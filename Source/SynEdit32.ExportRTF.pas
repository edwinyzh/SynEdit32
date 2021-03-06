{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynExportRTF.pas, released 2000-04-16.

The Original Code is partly based on the mwRTFExport.pas file from the
mwEdit component suite by Martin Waldenburg and other developers, the Initial
Author of this file is Michael Hieke.
Portions created by Michael Hieke are Copyright 2000 Michael Hieke.
Portions created by James D. Jacobson are Copyright 1999 Martin Waldenburg.
Unicode translation by Ma�l H�rz.
All Rights Reserved.

Contributors to the SynEdit project are listed in the Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id: SynExportRTF.pas,v 1.10.2.3 2008/09/14 16:24:59 maelh Exp $

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

Known Issues:
-------------------------------------------------------------------------------}

unit SynEdit32.ExportRTF;

{$I SynEdit32.inc}

interface

uses
  Windows,
  Graphics,
  RichEdit,
  SynEdit32.Export,
  SynEdit32.Unicode,
  Classes;

type
  TSynEdit32ExporterRTF = class(TSynEdit32CustomExporter)
  private
    FAttributesChanged: Boolean;
    FListColors: TList;
    function ColorToRTF(AColor: TColor): UnicodeString;
    function GetColorIndex(AColor: TColor): Integer;
  protected
    procedure FormatAfterLastAttribute; override;
    procedure FormatAttributeDone(BackgroundChanged, ForegroundChanged: Boolean;
      FontStylesChanged: TFontStyles); override;
    procedure FormatAttributeInit(BackgroundChanged, ForegroundChanged: Boolean;
      FontStylesChanged: TFontStyles); override;
    procedure FormatBeforeFirstAttribute(BackgroundChanged,
      ForegroundChanged: Boolean; FontStylesChanged: TFontStyles); override;
    procedure FormatNewLine; override;
    function GetFooter: UnicodeString; override;
    function GetFormatName: string; override;
    function GetHeader: UnicodeString; override;
    function ReplaceReservedChar(AChar: WideChar): UnicodeString; override;
    function UseBom: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear; override;
    function SupportedEncodings: TSynEncodings; override;
  published
    property Color;
    property DefaultFilter;
    property Encoding;
    property Font;
    property Highlighter;
    property Title;
    property UseBackground;
  end;

implementation

uses
  SynEdit32.StrConst,
  SysUtils;

{ TSynEdit32ExporterRTF }

constructor TSynEdit32ExporterRTF.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FListColors := TList.Create;
  FDefaultFilter := SYNS_FilterRTF;
  FClipboardFormat := RegisterClipboardFormat(CF_RTF);
  FEncoding := seUTF8;
end;

destructor TSynEdit32ExporterRTF.Destroy;
begin
  FListColors.Free;
  FListColors := nil;
  inherited Destroy;
end;

procedure TSynEdit32ExporterRTF.Clear;
begin
  inherited Clear;
  if Assigned(FListColors) then
    FListColors.Clear;
end;

function TSynEdit32ExporterRTF.ColorToRTF(AColor: TColor): UnicodeString;
var
  Col: Integer;
begin
  Col := ColorToRGB(AColor);
  Result := Format('\red%d\green%d\blue%d;', [GetRValue(Col), GetGValue(Col),
    GetBValue(Col)]);
end;

procedure TSynEdit32ExporterRTF.FormatAfterLastAttribute;
begin
  // no need to reset the font style here...
end;

procedure TSynEdit32ExporterRTF.FormatAttributeDone(BackgroundChanged,
  ForegroundChanged: Boolean; FontStylesChanged: TFontStyles);
const
  FontTags: array[TFontStyle] of UnicodeString = ('\b0', '\i0', '\ul0', '\strike0');
var
  AStyle: TFontStyle;
begin
  // nothing to do about the color, but reset the font style
  for AStyle := Low(TFontStyle) to High(TFontStyle) do
  begin
    if AStyle in FontStylesChanged then
    begin
      FAttributesChanged := True;
      AddData(FontTags[AStyle]);
    end;
  end;
end;

procedure TSynEdit32ExporterRTF.FormatAttributeInit(BackgroundChanged,
  ForegroundChanged: Boolean; FontStylesChanged: TFontStyles);
const
  FontTags: array[TFontStyle] of UnicodeString = ('\b', '\i', '\ul', '\strike');
var
  AStyle: TFontStyle;
begin
  // background color
  if BackgroundChanged then
  begin
    AddData(Format('\cb%d', [GetColorIndex(fLastBG)]));
    FAttributesChanged := True;
  end;
  // text color
  if ForegroundChanged then
  begin
    AddData(Format('\cf%d', [GetColorIndex(fLastFG)]));
    FAttributesChanged := True;
  end;
  // font styles
  for AStyle := Low(TFontStyle) to High(TFontStyle) do
    if AStyle in FontStylesChanged then
    begin
      AddData(FontTags[AStyle]);
      FAttributesChanged := True;
    end;
  if FAttributesChanged then
  begin
    AddData(' ');
    FAttributesChanged := False;
  end;
end;

procedure TSynEdit32ExporterRTF.FormatBeforeFirstAttribute(BackgroundChanged,
  ForegroundChanged: Boolean; FontStylesChanged: TFontStyles);
begin
  FormatAttributeInit(BackgroundChanged, ForegroundChanged, FontStylesChanged);
end;

procedure TSynEdit32ExporterRTF.FormatNewLine;
begin
  AddData(#13#10'\par ');
end;

function TSynEdit32ExporterRTF.GetColorIndex(AColor: TColor): Integer;
begin
  Result := FListColors.IndexOf(pointer(AColor));
  if Result = -1 then
    Result := FListColors.Add(pointer(AColor));
end;

function TSynEdit32ExporterRTF.GetFooter: UnicodeString;
begin
  Result := '}';
end;

function TSynEdit32ExporterRTF.GetFormatName: string;
begin
  Result := SYNS_ExporterFormatRTF;
end;

function TSynEdit32ExporterRTF.GetHeader: UnicodeString;
var
  i: Integer;

  function GetFontTable: UnicodeString;
  begin
    Result := '{\fonttbl{\f0\fmodern ' + Font.Name;
    Result := Result + ';}}'#13#10;
  end;

begin
  Result := '{\rtf1\ansi\ansicpg1252\uc1\deff0\deftab720' + GetFontTable;
  // all the colors
  Result := Result + '{\colortbl';
  for i := 0 to FListColors.Count - 1 do
    Result := Result + ColorToRTF(TColor(FListColors[i]));
  Result := Result + '}'#13#10;
  // title and creator comment
  Result := Result + '{\info{\comment Generated by the SynEdit RTF ' +
    'exporter}'#13#10;
  Result := Result + '{\title ' + fTitle + '}}'#13#10;
  if fUseBackground then
    Result := Result + { TODO: use background color } #13#10;
  Result := Result + Format('\deflang1033\pard\plain\f0\fs%d ',
    [2 * Font.Size]);
end;

function TSynEdit32ExporterRTF.ReplaceReservedChar(AChar: WideChar): UnicodeString;
begin
  Result := '';
  case AChar of
    '\': Result := '\\';
    '{': Result := '\{';
    '}': Result := '\}';
  end;
  if Ord(AChar) > 127 then
  begin
    if Ord(AChar) <= 255 then
      Result := '\''' + LowerCase(IntToHex(Ord(AChar), 2))
    else
      // SmallInt type-cast is necessary because RTF
      // uses signed 16-Bit Integer for Unicode characters
      Result := '\u' + IntToStr(SmallInt(AChar)) + '?';
  end;
end;

function TSynEdit32ExporterRTF.SupportedEncodings: TSynEncodings;
begin
  Result := [seUTF8];
end;

function TSynEdit32ExporterRTF.UseBom: Boolean;
begin
  Result := False;
end;

end.

