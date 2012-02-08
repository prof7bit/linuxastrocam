{ this file is part of linuxastrocam.lpr and contains the GUI main window

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

unit mainfrm;

{$mode objfpc}{$H+}

interface

uses
  Forms, Graphics, ExtCtrls, StdCtrls, ComCtrls, streamer;

type

  { TMainForm }

  TMainForm = class(TForm)
    BStart: TButton;
    BStop: TButton;
    CDarkDiff: TCheckBox;
    Display: TImage;
    ELastName: TEdit;
    EName: TEdit;
    LColor: TLabel;
    LExposure: TLabel;
    LGain: TLabel;
    LHue: TLabel;
    LName: TLabel;
    TColor: TTrackBar;
    TExposure: TTrackBar;
    TGain: TTrackBar;
    THue: TTrackBar;
    Timer1: TTimer;
    procedure BStartClick(Sender: TObject);
    procedure BStopClick(Sender: TObject);
    procedure CDarkDiffClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OnCameraFrame;
    procedure TColorChange(Sender: TObject);
    procedure TExposureChange(Sender: TObject);
    procedure TGainChange(Sender: TObject);
    procedure THueChange(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  MainForm: TMainForm;

implementation

{$R *.lfm}


{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  InitGlobals;
  Display.Width := CamDimensions.Width;
  Display.Height := CamDimensions.Height;
  with MainForm do begin
    Height := Display.Height + 32;
    Width := Display.Width + 286;
    with Constraints do begin
      MinHeight := Height;
      MaxHeight := Height;
      MinWidth := Width;
      MaxWidth := Width;
    end;
  end;
  Display.Picture.Bitmap.BeginUpdate(); // will stay in this state
  StartReceiver(Display, @OnCameraFrame);
  TColor.Position := V4lDevice.FVideo_Picture.colour;
  THue.Position := V4lDevice.FVideo_Picture.hue;
  TExposure.Position := V4lDevice.FVideo_Picture.contrast;
  TGain.Position := V4lDevice.FVideo_Picture.brightess;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  ShutdownAll;
end;

procedure TMainForm.OnCameraFrame;
begin
  ELastName.Text := SLastName;

  // it is alaways in updating state, only release this for a short moment
  Display.Picture.Bitmap.EndUpdate();
  Display.Picture.Bitmap.BeginUpdate();
end;

procedure TMainForm.TColorChange(Sender: TObject);
begin
  V4lDevice.SetPictureColor(TColor.Position);
end;

procedure TMainForm.TExposureChange(Sender: TObject);
begin
  // exposure is often set by the contrast setting
  V4lDevice.SetPictureContrast(TExposure.Position);
end;

procedure TMainForm.TGainChange(Sender: TObject);
begin
  // gain is often set with the brightness setting
  V4lDevice.SetPictureBrightness(TGain.Position);
end;

procedure TMainForm.THueChange(Sender: TObject);
begin
  V4lDevice.SetPictureHue(THue.Position);
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  // nothing. This is a workaround for really old GTK2 versions
  // which would not wake up on TThread.Synchronize()
end;

procedure TMainForm.CDarkDiffClick(Sender: TObject);
begin
  if CDarkDiff.Checked then begin
    InitDarkFrame;
  end;
  FlagDarkDiff := CDarkDiff.Checked;
end;

procedure TMainForm.BStartClick(Sender: TObject);
begin
  StartRecording(EName.Text);
  BStop.Enabled := True;
  BStart.Enabled := False;
end;

procedure TMainForm.BStopClick(Sender: TObject);
begin
  StopRecording;
  BStart.Enabled := True;
  BStop.Enabled := False;
end;


end.

