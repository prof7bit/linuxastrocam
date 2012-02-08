{ this file is part of linuxastrocam.lpr and contains the code of
  the worker threads that will handle the video, display it in the
  GUI and also handles the saving of the images to files.
  The actual v4l code is in the v4l1 unit and the FITS file format
  for saving is in the FitsObject unit.

  Copyright (C) 2011 Bernd Kreuss <prof7bit@googlemail.com>

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}

unit streamer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Graphics, v4l1, FitsObject;

const
  VideoDevice = '/dev/video0';
  VideoPalette = VIDEO_PALETTE_RGB24;

type
  TCamDimensions = record
    Width: Integer;
    Height: Integer;
  end;

  { the pixels as they are delivered from streamer though the pipe }
  PCamPixel = ^TCamPixel;
  TCamPixel = packed record
    Blue: byte;
    Green: byte;
    Red: byte;
  end;

  { TSaver }

  TSaver = Class(TThread)
    Display: TImage;
    Bitmap: TBitmap;
    constructor Create(ADisplay: TImage);
    procedure Execute; override;
  end;

  { TReceiver }

  TReceiver = class(TThread)
    Display: TImage;
    Saver: TSaver;
    MainthreadCallback: TThreadMethod;
    constructor Create(ADisplay: TImage; ACallback: TThreadMethod);
    destructor Destroy; override;
    procedure Execute; override;
  end;

var
  V4lDevice: TSimpleV4l1Device;
  Receiver: TReceiver;
  CamDimensions: TCamDimensions;
  CamImageSizeBytes: Integer;
  CamImageNumPixels: Integer;
  CamImage: PCamPixel;
  DarkImage: PCamPixel;
  CheckSumOld: Integer = 0;

  FlagDarkDiff: Boolean = False;
  FlagStreaming: Boolean = False; // used to stop the thred
  FlagStreamingDone: Boolean = False;
  FlagRecording: Boolean = False;
  FlagSavingThreadRuning: Boolean = False;
  FlagSavingThreadMustFree: Boolean = False;
  SSuffix: String;
  SDir: String;
  SLastName: String;
  IFileCount: Integer;


procedure InitGlobals;
procedure StartReceiver(ADisplay: TImage; ACallback: TThreadMethod);
procedure InitDarkFrame;
procedure StartRecording(AName: String);
procedure StopRecording;
procedure ShutdownAll;

implementation

procedure InitGlobals;
begin
  V4lDevice := TSimpleV4l1Device.Create(VideoDevice, VideoPalette);
  V4lDevice.Open;
  CamDimensions.Width := V4lDevice.FVideo_Window.width;
  CamDimensions.Height := V4lDevice.FVideo_Window.height;
  CamImageNumPixels := CamDimensions.Width * CamDimensions.Height;
  CamImageSizeBytes := CamImageNumPixels * SizeOf(TCamPixel);
  CamImage := Getmem(CamImageSizeBytes);
  DarkImage := Getmem(CamImageSizeBytes);
end;

procedure StartReceiver(ADisplay: TImage; ACallback: TThreadMethod);
begin
  Receiver := TReceiver.Create(ADisplay, ACallback);
end;

procedure InitDarkFrame;
begin
  Move(CamImage^, DarkImage^, CamImageSizeBytes);
end;

procedure StartRecording(AName: String);
begin
  IFileCount := 1; // IRIS wants the numbers to start at 1
  SSuffix := AName;
  SDir := FormatDateTime('YYYY-MM-DD-hh-nn-ss', Now);
  if AName <> '' then SDir := SDir + '-' + AName;
  MkDir(SDir);
  FlagRecording := True;
end;

procedure StopRecording;
begin
  FlagRecording := False;
  SSuffix := '';
  SDir := '';
end;

procedure ShutdownAll;
begin
  FlagStreaming := False; // signal the thread to end
  writeln('waiting for receiver thread to end');
  while not FlagStreamingDone do Sleep(100);
  writeln('receiver thread ended, now freeing it');
  Receiver.Free;
  writeln('closing and freeing the camera');
  V4lDevice.Close;
  V4lDevice.Free;
  writeln('shutdown procedure done');
end;

function RoundClamp(value: Double): Integer; inline;
begin
  Result := Round(value);
  if Result > 255 then
    Result := 255
  else if Result < 0 then
    Result := 0;
end;

procedure YUV420p_RGB24(src: PByte; dest: PCamPixel; width, height: Integer);
var
  UVWidth: Integer;
  UVRowOffs, VStart, UStart : Integer;
  PixNum, Col, Row : Integer;
  VPtr, UPtr: Integer;
  Y,U,V: integer;

begin
  UVWidth := width div 2;
  UStart := width * height;
  VStart := UStart + UStart div 4;

  PixNum := 0;
  for Row := 0 to height-1 do begin
    UVRowOffs := UVWidth * (Row div 2);
    VPtr := VStart + UVRowOffs;
    UPtr := UStart + UVRowOffs;
    for Col := 0 to width-1 do begin
      Y := src[PixNum];
      U := src[UPtr];
      V := src[VPtr];
      with dest[PixNum] do begin
        Blue := RoundClamp(1.164*(Y-16)+2.018*(U-128));
        Green := RoundClamp(1.164*(Y-16)-0.813*(V-128)-0.391*(U-128));
        Red := RoundClamp(1.164*(Y-16)+1.596*(V-128));
      end;
      Inc(PixNum);
      if (Col and 1) = 1 then begin
        Inc(VPtr);
        Inc(UPtr);
      end;
    end;
  end;
end;

procedure SubDark(var dark: Byte; var light: byte); inline;
var
  light2: Integer;
begin
  if light > dark then begin
    dark += 1;
    light2 := (light - dark) << 3;
    if light2 > 255 then light2 := 255;
    light := light2;
  end else begin
    if light < dark then begin
      dark -= 4;
    end;
    light := 0;
  end;
end;

{ TSaver }

constructor TSaver.Create(ADisplay: TImage);
begin
  FlagSavingThreadRuning := True;
  FlagSavingThreadMustFree := False;
  Display := ADisplay;
  Bitmap := TBitmap.Create;
  Bitmap.LoadFromRawImage(Display.Picture.Bitmap.RawImage, False);
  // now we have our own copy and the steamer thred can continue
  inherited Create(False);
end;

procedure TSaver.Execute;
var
  Fits: TFitsObject;
begin
  // no leading zeros in the file name because IRIS
  // wants it so. We do everything to please IRIS.
  SLastName := Format('%s/c%d.fit',[SDir, IFileCount]);
  writeln('saving ' + SLastName);
  Fits := TFitsObject.CreateFromBitmap(Bitmap);
  try
    Fits.SaveToFile(SLastName);
  except
    on E: Exception do writeln('could not save file: ' + E.Message);
  end;
  Fits.Free;
  Bitmap.Free;
  Inc(IFileCount);
  FlagSavingThreadMustFree := True;
  FlagSavingThreadRuning := False;
end;

{ TReceiver }

constructor TReceiver.Create(ADisplay: TImage; ACallback: TThreadMethod);
begin
  Display := ADisplay;
  MainthreadCallback := ACallback;
  inherited Create(False);
end;

destructor TReceiver.Destroy;
begin
  if FlagSavingThreadMustFree then begin
    writeln('freeing saver thread');
    Saver.Free;
    FlagSavingThreadMustFree := False;
  end;
  inherited Destroy;
end;

procedure TReceiver.Execute;
var
  x: Integer = 0;
  y: Integer = 0;
  i: Integer;

  Frame: PByte;

  // creating darkframe
  dark, light : Byte;     // value of one color
  pdark, plight : PByte;  // moving pointers in CamImage

  BytesPerLine: Integer;  // TBitmap/GUI specific
  BytesPerPixel: Integer; // TBitmap/GUI specific
  RedShift : Byte;        // bit shifts for individual colors
  GreenShift : Byte;
  BlueShift : Byte;

  LineOffset: Integer;    // start of line in pixels relative to origin
  LinePointer: PByte;     // start of line pointer in TBitmap
  PixelPointer: PByte;    // current pixel pointer in TBitmap


begin
  with Display.Picture.Bitmap do begin
    Width := CamDimensions.Width;
    Height := CamDimensions.Height;
    Clear;
    with RawImage do begin;
      BytesPerLine := Description.BytesPerLine;
      BytesPerPixel := Description.BitsPerPixel div 8;
      RedShift := Description.RedShift;
      GreenShift := Description.GreenShift;
      BlueShift := Description.BlueShift;
    end;
  end;

  FlagStreaming := True;
  FlagStreamingDone := False;
  while FlagStreaming do begin
    Frame := V4lDevice.GetNextFrame;

    case V4lDevice.FVideo_Picture.palette of
      VIDEO_PALETTE_RGB24:
        move(Frame^, CamImage^, CamImageSizeBytes);
      VIDEO_PALETTE_YUV420P:
        YUV420p_RGB24(Frame, CamImage, CamDimensions.Width, CamDimensions.Height);
    end;

    if FlagDarkDiff and not FlagRecording then begin
      pdark := PByte(DarkImage);
      plight := PByte(CamImage);
      for i:=CamImageSizeBytes-1 downto 0 do begin
        light := plight^;
        dark := pdark^;
        SubDark(dark, light);
        plight^ := light;
        pdark^ := dark;
        plight += 1;
        pdark += 1;
      end;
    end;

    LinePointer := Display.Picture.Bitmap.RawImage.Data;
    LineOffset := 0;
    for y:=0 to CamDimensions.Height-1 do begin
      PixelPointer := LinePointer;
      for x:=0 to CamDimensions.Width-1 do begin
        with CamImage[LineOffset + x] do begin
          PInteger(PixelPointer)^ := Red << RedShift
                                  or Green << GreenShift
                                  or Blue << BlueShift;
          PixelPointer += BytesPerPixel;
        end;
      end;
      LineOffset += CamDimensions.Width;
      LinePointer += BytesPerLine;
    end;

    if FlagSavingThreadMustFree then begin
      Saver.Free;
      FlagSavingThreadMustFree := False;
    end;

    if FlagRecording then begin
      if not FlagSavingThreadRuning then begin
        Saver:=TSaver.Create(Display);
      end else begin
        writeln('could not save one frame (still busy), dropping it.');
      end;
    end;

    if FlagStreaming then begin
      Synchronize(MainthreadCallback);
    end;
  end;

  if FlagSavingThreadRuning then begin;
    writeln('waiting for saver thread to end');
    while FlagSavingThreadRuning do Sleep(100);
    writeln('saver thread ended');
  end;

  FlagStreamingDone := True;
end;


end.
