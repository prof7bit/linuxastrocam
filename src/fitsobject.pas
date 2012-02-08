{ This unit implments a subset of the Flexible Image Transport System
  (the FITS file format) for Lazarus / Free Pascal.
  standards document: http://fits.gsfc.nasa.gov/fits_standard.html

  An object of type TFitsObject can be created for example from a TBitmap,
  additional headers or data can be added or existing ones modified and
  the object can be written as a FITS file to a stream or to a file.
  Reading and parsing an existing FITS file is not yet implemented.

  License is GNU LGPL 2 with FPC/LCL linking exception (see below).

  ***

  Copyright (C) 2011 Bernd Kreuss <prof7bit@googlemail.com>

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

unit FitsObject;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

type
  { EFitsInvalidData will be raised when composing a FITS object
  and wrong or invalid data is passed into one of the methods,
  for example strings are too long, etc. }
  EFitsInvalidData = Class(Exception);

  { TFitsHeaderCard (also often referred to as ascii card image) is an
  exactly 80 byte ascii string and contains one key-value pair. Many of
  these header cards will be contained in an header block. The name
  "card image" comes from the old days of punched cards where IBM cards
  were exactly 80 characters in length. }
  TFitsHeaderCard = Class(TObject)
    constructor Create(AKey: String; AValue: String; AddQuotes: Boolean);
    constructor Create(AKey: String; AValue: Integer);
    constructor Create(AKey: String; AValue: Extended);
    procedure SetKey(AKey: String);
    procedure SetValue(AValue: String; AddQuotes: Boolean);
    procedure SetValue(AValue: Integer);
    procedure SetValue(AValue: Extended);
    function GetKey: String;
    function GetValue: String;
    procedure SaveToStream(AStream: TStream);
  private
    FText : array[1..80] of Char;
  end;

  { TFitsHeaderBlock contains any amount of headers. The standard defines
  a header block as having exacty 2880 bytes length padded with 0x20,
  followed by additional header blocks of the same size if needed. For
  the sake of simplicity in this library we are defining the header block
  as having an arbitrary amount of header records (cards) and there is only
  one such block per HDU when the FITS object is in memory and the
  splitting and padding into 2880 byte blocks will only happen later when
  writing it to the stream}
  TFitsHeaderBlock = Class(TObject)
    constructor Create;
    destructor Destroy; override;
    procedure AddStdCards(BITPIX, DATAMAX, NAXIS1, NAXIS2: Integer; Gray: Boolean);
    procedure AddCard(AHeader: TFitsHeaderCard);
    function GetCard(AKey: String): TFitsHeaderCard;
    procedure SaveToStream(AStream: TStream);
  private
    FCards: array of TFitsHeaderCard;
  end;

  { TFitsDataBlock contains data}
  TFitsDataBlock = Class(TObject)
    constructor Create;
    constructor Create16x3From24Bitmap(ABitmap: TBitmap);
    constructor Create8x3From24Bitmap(ABitmap: TBitmap);
    constructor Create8x1From24Bitmap(ABitmap: TBitmap);
    destructor Destroy; override;
    procedure SaveToStream(AStream: TStream);
  private
    FData: Pointer;
    FSize: Integer;
  end;

  { TFitsHDU (HDU, Header-and-Data-Unit) contains a header block and a
  data block. There is at least one such HDU in each FITS file, the first
  one is called the primary HDU}
  TFitsHDU = Class(TObject)
    constructor Create;
    destructor Destroy; override;
    procedure SaveToStream(AStream: TStream);
  private
    FHeaderBlock: TFitsHeaderBlock;
    FDataBlock: TFitsDataBlock;
  public
    property HeaderBlock: TFitsHeaderBlock read FHeaderBlock;
    property DataBlock: TFitsDatablock read FDataBlock write FDataBlock;
  end;

  { TFitsObject is repesenting a FITS object which consists of
    one or more HDU objects}
  TFitsObject = class(TObject)
    constructor Create;
    destructor Destroy; override;
    constructor CreateFromBitmap(ABitmap: TBitmap);
    constructor CreateFromFile(AName: String);
    constructor CreateFromStream(AStream: TStream);
    procedure SaveToFile(AName: String);
    procedure SaveToStream(AStream: TStream);
  private
    FHDUs : array of TFitsHDU;
  public
    property Primary: TFitsHDU read FHDUs[0];
  end;

implementation

{ TFitsHeaderCard }

constructor TFitsHeaderCard.Create(AKey: String; AValue: String; AddQuotes: Boolean);
begin
  Inherited Create;
  SetKey(AKey);
  SetValue(AValue, AddQuotes);
end;

constructor TFitsHeaderCard.Create(AKey: String; AValue: Integer);
begin
  Create(AKey, IntToStr(AValue), False);
end;

constructor TFitsHeaderCard.Create(AKey: String; AValue: Extended);
begin
  Create(AKey, FloatToStr(AValue), False);
end;

procedure TFitsHeaderCard.SetKey(AKey: String);
var
  i, k: Integer;
begin
  if Length(AKey) > 8 then
    raise EFitsInvalidData.Create('header key exceeding 8 byte');

  AKey := UpperCase(AKey);
  for i := 1 to Length(AKey) do begin
    FText[i] := AKey[i];
  end;
  for k := i+1 to 8 do begin
    FText[k] := ' ';
  end;
end;

procedure TFitsHeaderCard.SetValue(AValue: String; AddQuotes: Boolean);
var
  i, k: Integer;
begin
  if AddQuotes then
    AValue := '''' + AValue + '''';
  if Length(AValue) > 70 then
    raise EFitsInvalidData.Create('header value exceeding 70 byte');

  FText[9] := '=';
  FText[10] := ' ';

  for i := 1 to Length(AValue) do begin
    FText[10+i] := AValue[i];
  end;
  for k := i+1 to 70 do begin
    FText[10+k] := ' ';
  end;
end;

procedure TFitsHeaderCard.SetValue(AValue: Integer);
begin
  SetValue(IntToStr(AValue), False);
end;

procedure TFitsHeaderCard.SetValue(AValue: Extended);
begin
  SetValue(FloatToStr(AValue), False);
end;

function TFitsHeaderCard.GetKey: String;
begin
  Result := Trim(LeftStr(FText, 8));
end;

function TFitsHeaderCard.GetValue: String;
begin
  Result := Trim(RightStr(FText, 70));
  if Length(Result) > 1 then begin
    if Result[1] = '''' then begin
      // return quoted strings without quotes
      Result := RightStr(Result, Length(Result) - 1);
      Result := LeftStr(Result, Length(Result) - 1);
    end;
  end;
end;

procedure TFitsHeaderCard.SaveToStream(AStream: TStream);
begin
  AStream.WriteBuffer(FText, SizeOf(FText));
end;


{ TFitsHeaderBlock }

constructor TFitsHeaderBlock.Create;
begin
  Inherited Create;

end;

destructor TFitsHeaderBlock.Destroy;
var
  Card: TFitsHeaderCard;
begin
  if Length(FCards) > 0 then begin
    for Card in FCards do begin
      Card.Free;
    end;
  end;
  SetLength(FCards, 0);
  inherited Destroy;
end;

procedure TFitsHeaderBlock.AddStdCards(BITPIX, DATAMAX, NAXIS1, NAXIS2: Integer; Gray: Boolean);
var
  Naxis: Integer;
begin
  if not BITPIX in [8, 16] then
    raise EFitsInvalidData.Create('Invalid BITPIX value');
  if (DATAMAX >= (1 << BITPIX)) or (DATAMAX < 1) then
    raise EFitsInvalidData.Create('Invalid DATAMAX value');
  if Gray then
    Naxis := 2
  else
    Naxis := 3;

  AddCard(TFitsHeaderCard.Create('BITPIX', BITPIX));
  AddCard(TFitsHeaderCard.Create('NAXIS', Naxis));
  AddCard(TFitsHeaderCard.Create('NAXIS1', NAXIS1));
  AddCard(TFitsHeaderCard.Create('NAXIS2', NAXIS2));
  if Naxis = 3 then
    AddCard(TFitsHeaderCard.Create('NAXIS3', 3)); // 3 colors
  AddCard(TFitsHeaderCard.Create('BSCALE', 1.0));
  AddCard(TFitsHeaderCard.Create('BZERO', 0.0));
  AddCard(TFitsHeaderCard.Create('DATAMAX', DATAMAX));
  AddCard(TFitsHeaderCard.Create('DATAMIN', 0));
  AddCard(TFitsHeaderCard.Create('MIPS-HI', DATAMAX)); // this initializes
  AddCard(TFitsHeaderCard.Create('MIPS-LO', 0));       // the visu of IRIS
end;

procedure TFitsHeaderBlock.AddCard(AHeader: TFitsHeaderCard);
var
  Cnt : Integer;
begin
  Cnt := Length(FCards);
  SetLength(FCards, Cnt+1);
  FCards[Cnt] := AHeader;
end;

function TFitsHeaderBlock.GetCard(AKey: String): TFitsHeaderCard;
var
  Card: TFitsHeaderCard;
begin
  Result := nil;
  for Card in FCards do begin
    if Card.GetKey = AKey then begin
      Result := Card;
      break;
    end;
  end;
end;

procedure TFitsHeaderBlock.SaveToStream(AStream: TStream);
var
  Card: TFitsHeaderCard;
  Bytes: Integer = 0;
  Remaining: Integer;
  i: Integer;
  sEND : array[0..2] of Char = 'END';
begin
  // the standard demands that the headers are written in blocks
  // of 2880 bytes (this is exactly 36 cards). Since full blocks
  // would fit together seamlessly we can just write all cards
  // each after the other without interruption.
  for Card in FCards do begin
    Card.SaveToStream(AStream);
    Bytes += 80;
  end;

  // write the mandatory END card (we haven't stored this in the
  // FCards array since it is not a real key-value pair, its more
  // like a marker that is always there but carries no payload.
  AStream.Write(sEND, 3);
  for i:=1 to 77 do begin
    AStream.WriteByte($20);
  end;
  Bytes += 80;

  // When done with all cards we must pad with 0x20 until the
  // total of written bytes is a multiple of 2880.
  Remaining := 2880 - (Bytes mod 2880);
  for i:=1 to Remaining do begin
    AStream.WriteByte($20);
  end;
end;


{ TFitsDataBlock }

constructor TFitsDataBlock.Create;
begin
  Inherited Create;
end;

constructor TFitsDataBlock.Create16x3From24Bitmap(ABitmap: TBitmap);
var
  x,y: Integer;
  DestPtr: PWord;    // the size in a BITPIX = 16 is one word per value
  SrcPtr: PInteger;  // the size of an RGB pixel in the source bitmap
  BytesPerLine: Integer;
begin
  FSize := ABitmap.Width * ABitmap.Height * 6; // 3 * 2 bytes per pixel
  FData := Getmem(FSize);

  BytesPerLine := ABitmap.RawImage.Description.BitsPerLine div 8;
  DestPtr := FData;

  // We will not use the full range of 0..16 bit, instead we will
  // shift the 8 bit values so that they occupy the most significant
  // 8 bits of a 15 bit value. $ff will end up as %0111111110000000
  // this is done because IRIS wants to use signed integers.

  // red
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := swap(word((SrcPtr^ and $ff0000) shr 9)); // FITS endianness!
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;

  // green
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := swap(word((SrcPtr^ and $ff00) shr 1));
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;

  // blue
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := swap(word((SrcPtr^ and $ff) shl 7));
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;
end;

constructor TFitsDataBlock.Create8x3From24Bitmap(ABitmap: TBitmap);
var
  x,y: Integer;
  DestPtr: PByte;    // the size in a BITPIX = 8 is one byte per value
  SrcPtr: PInteger;  // the size of an RGB pixel in the source bitmap
  BytesPerLine: Integer;
begin
  FSize := ABitmap.Width * ABitmap.Height * 3;
  FData := Getmem(FSize);

  BytesPerLine := ABitmap.RawImage.Description.BitsPerLine div 8;
  DestPtr := FData;

  // red
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := (SrcPtr^ >> 16) and $ff;
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;

  // green
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := (SrcPtr^ >> 8) and $ff;
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;

  // blue
  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := SrcPtr^ and $ff;
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;
end;

constructor TFitsDataBlock.Create8x1From24Bitmap(ABitmap: TBitmap);
var
  x,y: Integer;
  DestPtr: PByte;    // the size in a BITPIX = 8 is one byte per value
  SrcPtr: PInteger;  // the size of an RGB pixel in the source bitmap
  BytesPerLine: Integer;
begin
  FSize := ABitmap.Width * ABitmap.Height;
  FData := Getmem(FSize);

  BytesPerLine := ABitmap.RawImage.Description.BitsPerLine div 8;
  DestPtr := FData;

  for y:= ABitmap.Height-1 downto 0 do begin
    SrcPtr := PInteger(ABitmap.RawImage.Data + BytesPerLine * y);
    for x:=0 to ABitmap.Width-1 do begin
      DestPtr^ := (
                  ((SrcPtr^ >> 16) and $ff) +
                  ((SrcPtr^ >> 8) and $ff) +
                  (SrcPtr^ and $ff)
                ) div 3;
      DestPtr += 1;
      SrcPtr += 1;
    end;
  end;
end;

destructor TFitsDataBlock.Destroy;
begin
  if FData <> Nil then
    Freemem(FData, FSize);
  inherited Destroy;
end;

procedure TFitsDataBlock.SaveToStream(AStream: TStream);
var
  Remaining: Integer;
  i: Integer;
begin
  AStream.WriteBuffer(FData^, FSize);

  // padding with $00 to multiple of 2880
  Remaining := 2880 - (FSize mod 2880);
  for i:=1 to Remaining do begin
    AStream.WriteByte(0);
  end;
end;


{ TFitsHDU }

constructor TFitsHDU.Create;
begin
  Inherited Create;
  FHeaderBlock := TFitsHeaderBlock.Create;
  FDataBlock := nil // data block is optional, can be created later
end;

destructor TFitsHDU.Destroy;
begin
  FreeAndNil(FHeaderBlock);
  if FDataBlock <> nil then FreeAndNil(FDataBlock);
  inherited Destroy;
end;

procedure TFitsHDU.SaveToStream(AStream: TStream);
begin
  FHeaderBlock.SaveToStream(AStream);
  if FDataBlock <> nil then FDataBlock.SaveToStream(AStream);
end;


{ TFitsObject }

constructor TFitsObject.Create;
begin
  Inherited Create;

  // create the mandatory pimary HDU
  SetLength(FHDUs, 1);
  FHDUs[0] := TFitsHDU.Create;

  // this is now automatically also accessible via the property 'Primary'
  // and now we add the for all FITS mandatory card 'SIMPLE = T'
  Primary.HeaderBlock.AddCard(TFitsHeaderCard.Create('SIMPLE', '                   T', False));
end;

destructor TFitsObject.Destroy;
var
  HDU: TFitsHDU;
begin
  for HDU in FHDUs do begin
    HDU.Free;
  end;
  SetLength(FHDUs, 0);
  inherited Destroy;
end;

constructor TFitsObject.CreateFromBitmap(ABitmap: TBitmap);
begin
  Create;
  Primary.HeaderBlock.AddStdCards(16, 255 shl 7, ABitmap.Width, ABitmap.Height, False);
  Primary.DataBlock := TFitsDataBlock.Create16x3From24Bitmap(ABitmap);
end;

constructor TFitsObject.CreateFromFile(AName: String);
var
  Stream: TFileStream;
begin
  Create;

  raise EAbstractError.Create('sorry, this is not yet impmemented');

  Stream := TFileStream.Create(AName, fmOpenRead);
  CreateFromStream(Stream);
  Stream.Free;
end;

constructor TFitsObject.CreateFromStream(AStream: TStream);
begin
  Create;

  raise EAbstractError.Create('sorry, this is not yet impmemented');
end;

procedure TFitsObject.SaveToFile(AName: String);
var
  Stream : TFileStream;
begin
  Stream := TFileStream.Create(AName, fmCreate);
  SaveToStream(Stream);
  Stream.Free;
end;

procedure TFitsObject.SaveToStream(AStream: TStream);
var
  HDU: TFitsHDU;
begin
  for HDU in FHDUs do begin
    HDU.SaveToStream(AStream);
  end;
end;

end.

