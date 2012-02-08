{ Implements the bare minimum of v4l (and v4l2 indirectly though
  libv4l1.so), just enough to open the webcam, set the picture
  settings and grab images. It does not contain anything regarding
  tuners, audio, etc.

  v4l2 support is implemented through libv4l1 which will transparently
  and automatically emulate the old v4l1 API when the cam has a
  v4l2 driver. This will also add support for all known image formats
  and encodings which will be converted on the fly into uncompressed
  24 bit BGR (VIDEO_PALETTE_RGB24).

  Programming against the V4l1 API and then running it though a compatibility
  layer to support V4l2 might not be the most recommended way for many
  situations but I still need V4l1 support for some old exotic cameras and
  this seems to be the most pragmatic way of doing it.

  The API definitions from videodev.h were manually translated from FreeBSD's
  linux-kmod-compat re-implementation of the original Linux header file.

  ***

  Copyright (c) 2011 Bernd Kreuss <prof7bit@googlemail.com>

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at your
  option) any later version with the following modification:

  As a special exception, the copyright holders of this library give you
  permission to link this library with independent modules to produce an
  executable, regardless of the license terms of these independent modules,and
  to copy and distribute the resulting executable under terms of your choice,
  provided that you also meet, for each linked independent module, the terms
  and conditions of the license of that module. An independent module is a
  module which is not derived from or based on this library. If you modify
  this library, you may extend this exception to your version of the library,
  but you are not obligated to do so. If you do not wish to do so, delete this
  exception statement from your version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
  for more details.

  You should have received a copy of the GNU Library General Public License
  along with this library; if not, write to the Free Software Foundation,
  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}


unit v4l1;

{$mode objfpc}{$H+}

interface

const
  // these are used in the TVideo_Capability record
  VID_TYPE_CAPTURE = 1 ; { Can capture }
  VID_TYPE_TUNER = 2 ; { Can tune }
  VID_TYPE_TELETEXT = 4 ; { Does teletext }
  VID_TYPE_OVERLAY = 8 ; { Overlay onto frame buffer }
  VID_TYPE_CHROMAKEY = 16 ; { Overlay by chromakey }
  VID_TYPE_CLIPPING = 32 ; { Can clip }
  VID_TYPE_FRAMERAM = 64 ; { Uses the frame buffer memory }
  VID_TYPE_SCALES = 128 ; { Scalable }
  VID_TYPE_MONOCHROME = 256 ; { Monochrome only }
  VID_TYPE_SUBCAPTURE = 512 ; { Can capture subareas of the image }
  VID_TYPE_MPEG_DECODER = 1024 ; { Can decode MPEG streams }
  VID_TYPE_MPEG_ENCODER = 2048 ; { Can encode MPEG streams }
  VID_TYPE_MJPEG_DECODER = 4096 ; { Can decode MJPEG streams }
  VID_TYPE_MJPEG_ENCODER = 8192 ; { Can encode MJPEG streams }

  // these are used in the TVideo_Picture record
  VIDEO_PALETTE_GREY = 1; { Linear greyscale }
  VIDEO_PALETTE_HI240 = 2; { High 240 cube (BT848) }
  VIDEO_PALETTE_RGB565 = 3; { 565 16 bit RGB }
  VIDEO_PALETTE_RGB24 = 4; { 24bit RGB }
  VIDEO_PALETTE_RGB32 = 5; { 32bit RGB }
  VIDEO_PALETTE_RGB555 = 6; { 555 15bit RGB }
  VIDEO_PALETTE_YUV422 = 7; { YUV422 capture }
  VIDEO_PALETTE_YUYV = 8;
  VIDEO_PALETTE_UYVY = 9; { The great thing about standards is ... }
  VIDEO_PALETTE_YUV420 = 10;
  VIDEO_PALETTE_YUV411 = 11; { YUV411 capture }
  VIDEO_PALETTE_RAW = 12; { RAW capture (BT848) }
  VIDEO_PALETTE_YUV422P = 13; { YUV 4:2:2 Planar }
  VIDEO_PALETTE_YUV411P = 14; { YUV 4:1:1 Planar }
  VIDEO_PALETTE_YUV420P = 15; { YUV 4:2:0 Planar }
  VIDEO_PALETTE_YUV410P = 16; { YUV 4:1:0 Planar }
  VIDEO_PALETTE_PLANAR = 13; { start of planar entries }
  VIDEO_PALETTE_COMPONENT = 7; { start of component entries }

  // used in TVideo_Mbuf
  VIDEO_MAX_FRAME = 32;

type
  { will be filled by issuing a VIDIOCGCAP to get some
    capabilities of the device. This is the first thing
    one should do after opening the device}
  TVideo_Capability = record
    name: array[0..31] of char;
    typ: Integer;
    channels: Integer;
    audios: Integer;
    maxwidth: Integer;
    maxheight: Integer;
    minwidth: Integer;
    minheight: Integer;
  end;

  { This is used to get or set the picture settings with
    VIDIOCGPICT and VIDIOCSPICT. This is the next thing
    to do after querying the capabilities.}
  Tvideo_Picture = record
    brightess: Word;
    hue: Word;
    colour: Word;
    contrast: Word;
    whiteness: Word;
    depth: Word;
    palette: Word;
  end;

  { clipping regions, referenced in TVideo_Window. This is not
    something one needs for everyday use. Its only defined here
    for the sake of completeness because TVideo_Window mentions them.}
  Pclips = ^TClips;
  TClips = record
    x,y: Integer;
    width, height: Integer;
    next: Pclips;
  end;

  { This must be sent with a VIDIOCSWIN or queried with a VIDIOCGWIN
    to set (or get) the video size. before starting capturing. Usually
    you set it to the maximum width and height that is found in
    TVideo_Capabilities}
  TVideo_Window = record
    x,y : DWord;
    width, height: DWord;
    chromakey: DWord;
    flags: DWord;
    clips: Pclips;
    clipcount: Integer;
  end;

  { this is used to ask the driver for the size of the memory
    that should be mapped. Use it with VIDIOCGMBUF and then
    use the returned size value to mmmap() the device and
    after capturing you can use the offsets array to calculate
    the pointers to individual frames in the mapped memory }
  TVideo_Mbuf = record
    size: Integer;
    frames: Integer;
    offsets: array[0..VIDEO_MAX_FRAME-1] of Integer;
  end;

  { use this to request the capturing of exactloy one frame with
    VIDIOCMCAPTURE. It will immedately return. You must use
    VIDIOCSYNC to wait for this frame. VIDIOCMCAPTURE must be
    called for each frame. Usually you do it like the following,
    alternating between two frame numbers 0 and 1.

    VIDIOCMCAPTURE(0)
    while ... do begin
      VIDIOCMCAPTURE(1)       // start 1
      VIDIOCSYNC(0)           // wait for 0
      ... process the frame ...
      VIDIOCMCAPTURE(0)       // start 0
      VIDIOCSYNC(1)           // wait for 1
      ... process the frame ...
    end;
    }
  TVideo_Mmap = record
    frame: DWord;   // Frame (0..n-1)
    height: Integer;
    width: Integer;
    format: DWord;  // should be VIDEO_PALETTE_*
  end;


// the following were actually constants in the
// original headers but their values are computed
// by the C preprocessor at compile time with the
// help of a lot of nested macros, its actually
// easier to make them functions.

function VIDIOCGCAP: Cardinal;
function VIDIOCGPICT: Cardinal;
function VIDIOCSPICT: Cardinal;
function VIDIOCGWIN: Cardinal;
function VIDIOCSWIN: Cardinal;
function VIDIOCGMBUF: Cardinal;
function VIDIOCMCAPTURE: Cardinal;
function VIDIOCSYNC: Cardinal;


///////////////////////
// End of V4l Header //
///////////////////////


type
  { TSimpleV4l1Device implments something that will actually make use of
    all the above. It represents a webcam and will set the Device to the
    largest supported resolution and start capturing images. Its only
    a quick and dirty hack that works for my QuickCam Express but it
    illustrates the principle.
    Usage:

      Cam := TSimpleV4l1Device.Create('/dev/video0', VIDEO_PALETTE_RGB24);
      Cam.Open;
      while (WhatEver) do begin
        Data := Cam.GetNextFrame: // waits for the next frame
        // now use that pointer to copy
        // the frame and process it
      end;

    the methods can throw exceptions when the camera is not supported
    so you should enclose it all in try/except and don't forget to
    use Cam.Close afterwards; }
  TSimpleV4l1Device = class(TObject)
    FDevice: String;
    FHandle: Integer;
    FPalette: Word;
    FVideo_Capability: TVideo_Capability;
    FVideo_Picture: Tvideo_Picture;
    FVideo_Window: TVideo_Window;
    FVideo_Mbuf : TVideo_Mbuf;
    FVideo_Mmap : TVideo_Mmap;
    FBuf: PByte;
    FFrameNum: Integer;
    constructor Create(ADevice: String; APalette: Word);

    {Open the device and set all parameters so that capturing
    can begin. This will also trigger the very first Capture call
    with frame 0. the next Capture/Sync will then be 1/0, then
    0/1, etc.}
    procedure Open;

    {free the buffers and close the device}
    procedure Close;

    {use ioctl() (the wrapped function) from outside the object}
    function Ioctl(Request: Cardinal; Data: Pointer): Integer;

    { tell the driver to start capturing a frame. This will
    also toggle the frame number to the other of the two
    frames. A subsequant Sync will then wait for the frame
    that was captured before.}
    procedure Capture;

    { wait for the next frame.}
    procedure Sync;

    { get the pointer to the last sync'd frame }
    function GetLastFrame: PByte;

    { Capture, Sync and then return the Pointer to the new
      frame. This function will block until a new frame
      is available. Simply calling this in a loop is all
      you need to do to get streaming video from the cam. }
    function GetNextFrame: PByte;

    { get the picture settings, store them in FVideo_Picture }
    procedure GetPictureSettigs;

    { set the picture settings, that are in FVideo_Picture }
    procedure SetPictureSettings;

    { Set the color strength}
    procedure SetPictureColor(Color: Word);

    { Set the color hue}
    procedure SetPictureHue(Hue: Word);

    { Set the brightness (on some cameras this is the gain)}
    procedure SetPictureBrightness(Brightness: Word);

    { Set the contrast (on some cameras this is the exposure)}
    procedure SetPictureContrast(Contrast: Word);
  end;


{ The v4l_open/close/ioctl/etc... functions from the libv4l1.so are used
  instead of their original native couterparts since they will be able to
  fully emulate the old v4l1 behavior on v4l2 devices with v4l2 drivers.
  This automatically adds support for all new v2 devices. Also all the
  format conversion from all known v2 formats will be automatically done
  transparently on the fly into either RGB24 (BGR) or YUV240p. Every
  V4l2 cam will appear as a V4l1 cam capable of 24 bit uncompressed BGR}
function v4l1_open (filname: PChar; oflag: Integer): Integer;
  cdecl;external 'libv4l1.so.0';
function v4l1_close(fd: Integer): Integer;
  cdecl; external 'libv4l1.so.0';
function v4l1_ioctl(fd: Integer; request: Cardinal; data: Pointer): Integer;
  cdecl; external 'libv4l1.so.0';
function v4l1_read(fd: Integer; buffer: Pointer; n: Integer): Integer;
  cdecl; external 'libv4l1.so.0';
function v4l1_mmap(start: Pointer; length: Integer; prot: Integer;
  flags: Integer; fd: Integer; offset: Int64): Pointer;
  cdecl; external 'libv4l1.so.0';
function v4l1_munmap(start: Pointer; length: Integer): Integer;
  cdecl; external 'libv4l1.so.0';


// the functions below are only for debugging purposes,
// to print the contents of some records to the console.

procedure DebugPrintCapabilities(cap: TVideo_Capability);
procedure DebugPrintPicture(pict: Tvideo_Picture);
procedure DebugPrintWindow(win: TVideo_Window);

implementation
uses
  SysUtils, BaseUnix, kernelioctl;

{ the ioctl "constants" implemented as functions }

function VIDIOCGCAP: Cardinal;
begin
  Result := _IOR(ord('v'), 1, SizeOf(TVideo_Capability));
end;

function VIDIOCGPICT: Cardinal;
begin
  Result := _IOR(ord('v'), 6, SizeOf(Tvideo_Picture));
end;

function VIDIOCSPICT: Cardinal;
begin
  Result := _IOW(ord('v'), 7, SizeOf(Tvideo_Picture));
end;

function VIDIOCGWIN: Cardinal;
begin
  Result := _IOR(ord('v'), 9, SizeOf(TVideo_Window));
end;

function VIDIOCSWIN: Cardinal;
begin
  Result := _IOW(ord('v'),10, SizeOf(TVideo_Window));
end;

function VIDIOCGMBUF: Cardinal;
begin
  Result := _IOR(ord('v'), 20, SizeOf(TVideo_Mbuf));
end;

function VIDIOCMCAPTURE: Cardinal;
begin
  Result :=	_IOW(ord('v'), 19, SizeOf(TVideo_Mmap));
end;

function VIDIOCSYNC: Cardinal;
begin
  Result := _IOW(ord('v'), 18, SizeOf(Integer));
end;

{ TSimpleV4l1Device }

constructor TSimpleV4l1Device.Create(ADevice: String; APalette: Word);
begin
  FDevice := ADevice;
  FPalette := APalette;
end;

procedure TSimpleV4l1Device.Open;
begin
  // open the device
  FHandle := v4l1_open(pchar(FDevice), O_RDWR);
  if FHandle = -1 then
    raise Exception.Create('could not open video device ' + FDevice);

  // get cpability
  if v4l1_ioctl(FHandle, VIDIOCGCAP, @FVideo_Capability) < 0 then
    raise Exception.Create('could not query capabilities');
  DebugPrintCapabilities(FVideo_Capability);

  // get picture settings (and set palette)
  GetPictureSettigs;
  DebugPrintPicture(FVideo_Picture);
  if FVideo_Picture.palette <> FPalette then begin
    writeln('trying to set desired palette');
    FVideo_Picture.palette := FPalette;
    try
      SetPictureSettings; // will throw exception if palette is not supported.
    except
      writeln('could not set palette');
      raise Exception.Create('could not set palette');
    end;
    DebugPrintPicture(FVideo_Picture);
  end;

  // set video window
  with FVideo_Window do begin
    x := 0;
    y := 0;
    width := FVideo_Capability.maxwidth;
    height := FVideo_Capability.maxheight;
    chromakey := 0;
    flags := 0;
    clips := Nil;
    clipcount := 0;
  end;
  if v4l1_ioctl(FHandle, VIDIOCSWIN, @FVideo_Window) < 0 then
    raise Exception.Create('could not set video window');

  // get video window
  if v4l1_ioctl(FHandle, VIDIOCGWIN, @FVideo_Window) < 0 then
    raise Exception.Create('could not query video window');
  DebugPrintWindow(FVideo_Window);

  // ask the driver how much memory to mmap and do it
  if v4l1_ioctl(FHandle, VIDIOCGMBUF, @FVideo_Mbuf) < 0 then
    raise Exception.Create('could not query VIDIOCGMBUF');
  FBuf := v4l1_mmap(nil, FVideo_Mbuf.size, PROT_READ, MAP_SHARED, FHandle, 0);
  FFrameNum := 0;

  Capture; // start capturing the first frame already
end;

procedure TSimpleV4l1Device.Close;
begin
  v4l1_munmap(FBuf, FVideo_Mbuf.size);
  v4l1_close(FHandle);
end;

function TSimpleV4l1Device.Ioctl(Request: Cardinal; Data: Pointer): Integer;
begin
  Result := v4l1_ioctl(FHandle, Request, Data);
end;

procedure TSimpleV4l1Device.Capture;
begin
  FVideo_Mmap.format := FVideo_Picture.palette;
  FVideo_Mmap.height := FVideo_Window.height;
  FVideo_Mmap.width := FVideo_Window.width;
  FVideo_Mmap.frame := FFrameNum;
  if v4l1_ioctl(FHandle, VIDIOCMCAPTURE, @FVideo_Mmap) < 0 then
    raise Exception.Create('could not send VIDIOCMCAPTURE');

  // now we switch to the other of the two frame numbers. The
  // application will now call Sync on the other frame which
  // has already been capturing for a bit longer.
  FFrameNum := 1 - FFrameNum;
end;

procedure TSimpleV4l1Device.Sync;
begin
  if v4l1_ioctl(FHandle, VIDIOCSYNC, @FFrameNum) < 0 then
    raise Exception.Create('could not do VIDIOCSYNC');
end;

function TSimpleV4l1Device.GetLastFrame: PByte;
begin
  Result := FBuf + FVideo_Mbuf.offsets[FFrameNum];
end;

function TSimpleV4l1Device.GetNextFrame: PByte;
begin
  Capture;
  Sync;
  Result := GetLastFrame;
end;

procedure TSimpleV4l1Device.GetPictureSettigs;
begin
  if v4l1_ioctl(FHandle, VIDIOCGPICT, @FVideo_Picture) < 0 then
    raise Exception.Create('could not query picture settings');
end;

procedure TSimpleV4l1Device.SetPictureSettings;
begin
  if v4l1_ioctl(FHandle, VIDIOCSPICT, @FVideo_Picture) < 0 then
    raise Exception.Create('could not set picture settings');
end;

procedure TSimpleV4l1Device.SetPictureColor(Color: Word);
begin
  GetPictureSettigs;
  FVideo_Picture.colour := Color;
  SetPictureSettings;
end;

procedure TSimpleV4l1Device.SetPictureHue(Hue: Word);
begin
  GetPictureSettigs;
  FVideo_Picture.hue := Hue;
  SetPictureSettings;
end;

procedure TSimpleV4l1Device.SetPictureBrightness(Brightness: Word);
begin
  GetPictureSettigs;
  FVideo_Picture.brightess := Brightness;
  SetPictureSettings;
end;

procedure TSimpleV4l1Device.SetPictureContrast(Contrast: Word);
begin
  GetPictureSettigs;
  FVideo_Picture.contrast := Contrast;
  SetPictureSettings;
end;


procedure DebugPrintCapabilities(cap: TVideo_Capability);
var
  captyp : String = '';
begin
  if (cap.typ and VID_TYPE_CAPTURE) <> 0 then captyp += 'VID_TYPE_CAPTURE ';
  if (cap.typ and VID_TYPE_TUNER) <> 0 then captyp += 'VID_TYPE_TUNER ';
  if (cap.typ and VID_TYPE_TELETEXT) <> 0 then captyp += 'VID_TYPE_TELETEXT ';
  if (cap.typ and VID_TYPE_OVERLAY) <> 0 then captyp += 'VID_TYPE_OVERLAY ';
  if (cap.typ and VID_TYPE_CHROMAKEY) <> 0 then captyp += 'VID_TYPE_CHROMAKEY ';
  if (cap.typ and VID_TYPE_CLIPPING) <> 0 then captyp += 'VID_TYPE_CLIPPING ';
  if (cap.typ and VID_TYPE_FRAMERAM) <> 0 then captyp += 'VID_TYPE_FRAMERAM ';
  if (cap.typ and VID_TYPE_SCALES) <> 0 then captyp += 'VID_TYPE_SCALES ';
  if (cap.typ and VID_TYPE_MONOCHROME) <> 0 then captyp += 'VID_TYPE_MONOCHROME ';
  if (cap.typ and VID_TYPE_SUBCAPTURE) <> 0 then captyp += 'VID_TYPE_SUBCAPTURE ';
  if (cap.typ and VID_TYPE_MPEG_DECODER) <> 0 then captyp += 'VID_TYPE_MPEG_DECODER ';
  if (cap.typ and VID_TYPE_MPEG_ENCODER) <> 0 then captyp += 'VID_TYPE_MPEG_ENCODER ';
  if (cap.typ and VID_TYPE_MJPEG_DECODER) <> 0 then captyp += 'VID_TYPE_MJPEG_DECODER ';
  if (cap.typ and VID_TYPE_MJPEG_ENCODER) <> 0 then captyp += 'VID_TYPE_MJPEG_ENCODER ';

  writeln('video_capability');
  writeln('       Name: ' + cap.name);
  writeln('        typ: ' + captyp);
  writeln('   channels: ' + IntToStr(cap.channels));
  writeln('     audios: ' + IntToStr(cap.audios));
  writeln('   maxwidth: ' + IntToStr(cap.maxwidth));
  writeln('  maxheight: ' + IntToStr(cap.maxheight));
  writeln('   minwidth: ' + IntToStr(cap.minwidth));
  writeln('  minheight: ' + IntToStr(cap.minheight));
  writeln;
end;

procedure DebugPrintPicture(pict: Tvideo_Picture);
var
  palette: String;
begin
  if pict.palette = VIDEO_PALETTE_GREY then palette := 'VIDEO_PALETTE_GREY';
  if pict.palette = VIDEO_PALETTE_HI240 then palette := 'VIDEO_PALETTE_HI240';
  if pict.palette = VIDEO_PALETTE_RGB565 then palette := 'VIDEO_PALETTE_RGB565';
  if pict.palette = VIDEO_PALETTE_RGB24 then palette := 'VIDEO_PALETTE_RGB24';
  if pict.palette = VIDEO_PALETTE_RGB32 then palette := 'VIDEO_PALETTE_RGB32';
  if pict.palette = VIDEO_PALETTE_RGB555 then palette := 'VIDEO_PALETTE_RGB555';
  if pict.palette = VIDEO_PALETTE_YUV422 then palette := 'VIDEO_PALETTE_YUV422';
  if pict.palette = VIDEO_PALETTE_YUYV then palette := 'VIDEO_PALETTE_YUYV';
  if pict.palette = VIDEO_PALETTE_UYVY then palette := 'VIDEO_PALETTE_UYVY';
  if pict.palette = VIDEO_PALETTE_YUV420 then palette := 'VIDEO_PALETTE_YUV420';
  if pict.palette = VIDEO_PALETTE_YUV411 then palette := 'VIDEO_PALETTE_YUV411';
  if pict.palette = VIDEO_PALETTE_RAW then palette := 'VIDEO_PALETTE_RAW';
  if pict.palette = VIDEO_PALETTE_YUV422P then palette := 'VIDEO_PALETTE_YUV422P';
  if pict.palette = VIDEO_PALETTE_YUV411P then palette := 'VIDEO_PALETTE_YUV411P';
  if pict.palette = VIDEO_PALETTE_YUV420P then palette := 'VIDEO_PALETTE_YUV420P';
  if pict.palette = VIDEO_PALETTE_YUV410P then palette := 'VIDEO_PALETTE_YUV410P';
  if pict.palette = VIDEO_PALETTE_PLANAR then palette := 'VIDEO_PALETTE_PLANAR';
  if pict.palette = VIDEO_PALETTE_COMPONENT then palette := 'VIDEO_PALETTE_COMPONENT';

  writeln('video_picture');
  writeln(' brightness: ' + IntToStr(pict.brightess));
  writeln('        hue: ' + IntToStr(pict.hue));
  writeln('     colour: ' + IntToStr(pict.colour));
  writeln('   contrast: ' + IntToStr(pict.contrast));
  writeln('  whiteness: ' + IntToStr(pict.whiteness));
  writeln('      depth: ' + IntToStr(pict.depth));
  writeln('    palette: ' + palette);
  writeln;
end;

procedure DebugPrintWindow(win: TVideo_Window);
begin
  writeln('video_window:');
  writeln('               x: ' + IntToStr(win.x));
  writeln('               y: ' + IntToStr(win.y));
  writeln('           width: ' + IntToStr(win.width));
  writeln('          height: ' + IntToStr(win.height));
  writeln('       chromakey: ' + IntToStr(win.chromakey));
  writeln('           flags: ' + IntToStr(win.flags));
  writeln(Format(' clips (pointer): %p', [win.clips]));
  writeln('       clipcount: ' + IntToStr(win.clipcount));
  writeln;
end;

end.

