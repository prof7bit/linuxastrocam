{ linuxastrocam

  Capture images from a v4l webcam with the help of v4l's command line
  tools (streamer, v4lctl), display the streaming video in a GUI while
  allowing to adjust camera settigs and store a series of frames
  directly into FITS files that are usable in astrosurf IRIS.

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

program linuxastrocam;

{$mode objfpc}{$H+}

uses
  cthreads, Interfaces, Forms, LCL, Classes, mainfrm;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

