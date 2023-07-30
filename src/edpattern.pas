unit EdPattern;

{$mode ObjFPC}

interface

uses
  Adlib, Utils;

var
  IsPatternEdit: Boolean = False;

procedure RenderCommonTexts; 
procedure ResetParams;
procedure RenderPatternInfo;
procedure Loop;

implementation

uses
  Input, Keyboard, Screen, Formats, EdSong, Player;

const            
  PATTERN_SCREEN_START_X = 4;
  PATTERN_SCREEN_START_Y = 11;
  PATTERN_SCREEN_SIZE = 11;
  PATTERN_CHANNEL_WIDE = 8;

var
  VirtualSheetPointer: PWord;
  CurPattern: PNepperPattern;
  CurPatternIndex: Byte;
  Anchor: Byte = 0;
  CurChannel: Byte = 0;
  CurCell: Byte = 0;
  CurCellPart: Byte = 0;
  CurOctave: Byte = 4;
  CurStep: Byte = 1;
  IsEditMode: Boolean = True;
  GS2: String2;
  GS3: String3;

procedure ResetParams;
begin
  if CurChannel > NepperRec.ChannelCount - 1 then
    CurChannel := NepperRec.ChannelCount - 1;
  CurCellPart := 0;
  CurOctave := 4;
end;

procedure WriteTextSync(const X, Y, Attr: Byte; const S: String80; MaxLen: Byte = 0);
begin
  WriteText(X, Y, Attr, S, MaxLen);
  ScreenPointer := VirtualSheetPointer;
  WriteText(X, Y - PATTERN_SCREEN_START_Y + Anchor, Attr, S, MaxLen);
  ScreenPointer := ScreenPointerBackup;
end;

procedure RenderEditModeText;
begin
  if IsEditMode then
    WriteText(58, 9, $03, 'EDIT')
  else
    WriteText(58, 9, $03, '', 4);
end;

procedure RenderOctave; inline;
begin
  WriteText(70, 9, $0F, Char(CurOctave + Byte('0')));
end; 

procedure RenderPatternIndex; inline;
var
  S: String2;
begin
  HexStrFast2(CurPatternIndex, S);
  WriteText(24, 9, $F, S, 2);
end;

procedure RenderInstrument; inline;
var
  S: String2;
  PC: PNepperChannel;
begin
  PC := @CurPattern^[CurChannel];
  HexStrFast2(PC^.InstrumentIndex, S);
  WriteText(33, 9, $F, S, 2);
  WriteText(36, 9, $F, NepperRec.Instruments[PC^.InstrumentIndex].Name, 20);
end;

procedure RenderStep; inline;
begin
  WriteText(77, 9, $0F, Char(CurStep + Byte('0')));
end;

// Time critical function, process all pattern data to a buffer for fast scrolling
procedure RenderPatternInfo;
var
  I, J: ShortInt;
  W: Word;
  PW: PWord;
  PC: PNepperChannelCells;
begin
  FillChar(VirtualSheetPointer[0], 80*64*2, 0);
  PW := VirtualSheetPointer;
  for I := 0 to $3F do
  begin
    GS2[1] := BASE16_CHARS[Byte(I shr 4) and $F];
    GS2[2] := BASE16_CHARS[Byte(I) and $F];
    WriteTextFast2(PW, 03, GS2);
    Inc(PW, 80);
  end;
  for J := 0 to NepperRec.ChannelCount - 1 do
  begin
    PW := VirtualSheetPointer + (J * PATTERN_CHANNEL_WIDE + 4);
    PC := @CurPattern^[J].Cells;
    for I := 0 to $3F do
    begin
      if PC^[I].Note.Note = 0 then
        WriteTextFast3(PW, COLOR_LABEL, '---')
      else
      begin
        WriteTextFast2(PW, COLOR_LABEL, ADLIB_NOTESYM_TABLE[PC^[I].Note.Note]);
        WriteTextFast1(PW + 2, COLOR_LABEL, Char(PC^[I].Note.Octave + Byte('0')));
      end;
      W := Word(PC^[I].Effect);
      GS3[1] := BASE16_CHARS[Byte(W shr 8) and $F];
      GS3[2] := BASE16_CHARS[Byte(W shr 4) and $F];
      GS3[3] := BASE16_CHARS[Byte(W) and $F];
      WriteTextFast3(PW + 3, $0F, GS3);
      PW := PW + 80;
    end;
  end;
  PW := ScreenPointer + 80 * PATTERN_SCREEN_START_Y;
  Move(VirtualSheetPointer[80 * Anchor], PW[0], PATTERN_SCREEN_SIZE*80*2);
  RenderEditModeText;
  RenderOctave;
  RenderPatternIndex;
  RenderInstrument;
  RenderStep;
end;

procedure RenderPatternInfoOneChannel(const Channel: Byte);
var
  I, J: ShortInt;
  W: Word;
  PW: PWord;
  PC: PNepperChannelCells;
begin
  J := Channel;
  PW := VirtualSheetPointer + (J * PATTERN_CHANNEL_WIDE + 4);
  PC := @CurPattern^[J].Cells;
  for I := 0 to $3F do
  begin
    if PC^[I].Note.Note = 0 then
      WriteTextFast3(PW, COLOR_LABEL, '---')
    else
    begin
      WriteTextFast2(PW, COLOR_LABEL, ADLIB_NOTESYM_TABLE[PC^[I].Note.Note]);
      WriteTextFast1(PW + 2, COLOR_LABEL, Char(PC^[I].Note.Octave + Byte('0')));
    end;
    W := Word(PC^[I].Effect);
    GS3[1] := BASE16_CHARS[Byte(W shr 8) and $F];
    GS3[2] := BASE16_CHARS[Byte(W shr 4) and $F];
    GS3[3] := BASE16_CHARS[Byte(W) and $F];
    WriteTextFast3(PW + 3, $0F, GS3);
    PW := PW + 80;
  end;
  PW := ScreenPointer + 80 * PATTERN_SCREEN_START_Y;
  Move(VirtualSheetPointer[80 * Anchor], PW[0], PATTERN_SCREEN_SIZE*80*2);
end;

procedure RenderCommonTexts;
begin
  WriteText(0, 0, $1F, '                                   - Nepper -', 80);
  WriteText(0, 1, $0E, '     [F2] Song/Pattern Editor  [F3] Instrument Editor  [ESC] Exit Nepper');

  WriteText(0, 3, $4E, ' SONG DATA    ');
  WriteText(0, 5, COLOR_LABEL, 'Song name:');
  WriteText(63, 5, COLOR_LABEL, 'SPECIAL COMMANDS:');
  WriteText(0, 6, COLOR_LABEL, ' Position:');
  WriteText(63, 6, COLOR_LABEL, '[R] For Repeat');
  WriteText(0, 7, COLOR_LABEL, '  Pattern:');
  WriteText(63, 7, COLOR_LABEL, '[H] For Halt');

  WriteText(0, 9, $4E, ' PATTERN DATA ');
  WriteText(16, 9, COLOR_LABEL, 'Pattern:');
  WriteText(27, 9, COLOR_LABEL, 'Instr:');
  WriteText(63, 9, COLOR_LABEL, 'Octave:');
  WriteText(72, 9, COLOR_LABEL, 'Step:');

  WriteText(0, 23, $0A, '');
  WriteText(0, 24, $0A, '');

  RenderSongInfo;
  RenderPatternInfo;
end;

procedure RenderTexts;
begin      
  WriteText(0, 0, $1A, 'PATTERN EDIT');
  WriteText(0, 23, $0A, '[TAB] Song [INS-DEL] I/D  [<>] Instr.sel   [SF-UP/DN] Step  [F5-F7] Cut/Cpy/P', 80);
  WriteText(0, 24, $0A, '[SPC] P/S  [CR] Edit mode [+-] Pattern.sel [SF-0..6] Octave  ', 80);
end;

procedure LoopEditPattern;
var
  S: String3;
  PC: PNepperChannel;
  W: Word;
  PW: PWord;
  OldInputCursor: Byte;

  procedure MoveDown(Step: Byte);
  begin
    if CurCell + Step > $3F then
      Step := $3F - CurCell;
    Inc(CurCell, Step);
    if CurCell - Anchor >= PATTERN_SCREEN_SIZE then
    begin
      Anchor := CurCell - PATTERN_SCREEN_SIZE + 1;
      PW := ScreenPointer + 80 * PATTERN_SCREEN_START_Y;
      Move(VirtualSheetPointer[80 * Anchor], PW[0], PATTERN_SCREEN_SIZE*80*2);
      Screen.SetCursorPosition(CursorX, PATTERN_SCREEN_START_Y + PATTERN_SCREEN_SIZE - 1);
    end else
    begin
      Screen.SetCursorPosition(CursorX, CursorY + Step);
    end;
  end;

  procedure MoveUp(Step: Byte);
  begin
    if ShortInt(CurCell) - ShortInt(Step) < 0 then
      Step := CurCell;
    Dec(CurCell, Step);
    if CurCell < Anchor then
    begin
      Anchor := CurCell;
      PW := ScreenPointer + 80 * PATTERN_SCREEN_START_Y;
      Move(VirtualSheetPointer[80 * Anchor], PW[0], PATTERN_SCREEN_SIZE*80*2);
      Screen.SetCursorPosition(CursorX, PATTERN_SCREEN_START_Y);
    end else
    begin
      Screen.SetCursorPosition(CursorX, CursorY - Step);
    end;
  end;

  procedure SetTone(const Note, Octave: Byte);
  begin
    if (Note <> 0) or (Octave <> 0) then
    begin
      Adlib.SetInstrument(8, @NepperRec.Instruments[PC^.InstrumentIndex]);
      AdLib.NoteClear(8);
      Adlib.NoteOn(8, Note, Octave);
    end;
    if IsEditMode then
    begin
      PC^.Cells[CurCell].Note.Note := Note;
      PC^.Cells[CurCell].Note.Octave := Octave;
      if (Note = 0) and (Octave = 0) then
      begin
        WriteTextSync(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE)    , PATTERN_SCREEN_START_Y + CurCell - Anchor, COLOR_LABEL, '---', 3);
      end else
      begin
        WriteTextSync(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE)    , PATTERN_SCREEN_START_Y + CurCell - Anchor, COLOR_LABEL, ADLIB_NOTESYM_TABLE[Note], 2);
        WriteTextSync(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE) + 2, PATTERN_SCREEN_START_Y + CurCell - Anchor, COLOR_LABEL, Char(Octave + Byte('0')), 1);
        MoveDown(CurStep);
      end;
    end;
  end;

  procedure InsertTone;
  var
    I: Byte;
  begin
    for I := $3F downto CurCell + 1 do
    begin
      PC^.Cells[I] := PC^.Cells[I - 1];
    end;
    FillChar(PC^.Cells[CurCell], SizeOf(PC^.Cells[CurCell]), 0);
    RenderPatternInfoOneChannel(CurChannel);
  end;

  procedure DeleteTone;
  var
    I: Byte;
  begin
    for I := CurCell to $3E do
    begin
      PC^.Cells[I] := PC^.Cells[I + 1];
    end;
    FillChar(PC^.Cells[$3F], SizeOf(PC^.Cells[$3F]), 0);
    RenderPatternInfoOneChannel(CurChannel);
  end;

  procedure EditTone;
  begin
    case KBInput.CharCode of
      'z':
        begin
          SetTone(1, CurOctave);
        end;
      's':
        begin
          SetTone(2, CurOctave);
        end;    
      'x':
        begin
          SetTone(3, CurOctave);
        end;
      'd':
        begin
          SetTone(4, CurOctave);
        end;
      'c':
        begin
          SetTone(5, CurOctave);
        end;
      'v':
        begin
          SetTone(6, CurOctave);
        end;
      'g':
        begin
          SetTone(7, CurOctave);
        end;
      'b':
        begin
          SetTone(8, CurOctave);
        end;
      'h':
        begin
          SetTone(9, CurOctave);
        end;
      'n':
        begin
          SetTone(10, CurOctave);
        end;
      'j':
        begin
          SetTone(11, CurOctave);
        end;
      'm':
        begin
          SetTone(12, CurOctave);
        end;
      //
      'q':
        begin
          SetTone(1, CurOctave + 1);
        end;
      '2':
        begin
          SetTone(2, CurOctave + 1);
        end;
      'w':
        begin
          SetTone(3, CurOctave + 1);
        end;
      '3':
        begin
          SetTone(4, CurOctave + 1);
        end;
      'e':
        begin
          SetTone(5, CurOctave + 1);
        end;
      'r':
        begin
          SetTone(6, CurOctave + 1);
        end;
      '5':
        begin
          SetTone(7, CurOctave + 1);
        end;
      't':
        begin
          SetTone(8, CurOctave + 1);
        end;
      '6':
        begin
          SetTone(9, CurOctave + 1);
        end;
      'y':
        begin
          SetTone(10, CurOctave + 1);
        end;
      '7':
        begin
          SetTone(11, CurOctave + 1);
        end;
      'u':
        begin
          SetTone(12, CurOctave + 1);
        end;
      '0':
        begin
          SetTone(0, 0);
        end
      else
        case KBInput.ScanCode of
          SCAN_INS:
            begin
              InsertTone;
            end;                  
          SCAN_DEL:
            begin
              DeleteTone;
            end;
        end;
    end;
  end;

begin
  PC := @CurPattern^[CurChannel];
  // Edit effect
  if CurCellPart = 1 then
  begin
    W := Word(PC^.Cells[CurCell].Effect);
    OldInputCursor := Input.InputCursor;
    Input.InputHex3(S, W, $FFF);
    if IsEditMode then
    begin
      Word(PC^.Cells[CurCell].Effect) := W;
      WriteTextSync(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE) + (CurCellPart * 3), PATTERN_SCREEN_START_Y + CurCell - Anchor, $0F, S, 3);
      if KBInput.ScanCode = $FF then
      begin 
        if Input.InputCursor <> OldInputCursor then
        begin
          Input.InputCursor := OldInputCursor;
          Dec(CursorX);
        end;
        MoveDown(CurStep);
      end;
    end;
  end else
  // Edit tone
  begin
    EditTone;
  end;
  // Navigate
  if KBInput.ScanCode < $FE then
  begin
    case KBInput.ScanCode of
      SCAN_LEFT:
        begin
          if CurCellPart = 0 then
          begin
            if CurChannel > 0 then
            begin
              CurCellPart := 1;
              Input.InputCursor := 3;
              Dec(CurChannel);
              Screen.SetCursorPosition(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE) + (CurCellPart * 3)+ (Input.InputCursor - 1), PATTERN_SCREEN_START_Y + CurCell - Anchor);
              RenderInstrument;
            end;
          end else
          begin
            CurCellPart := 0;
            Screen.SetCursorPosition(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE) + (CurCellPart * 3), PATTERN_SCREEN_START_Y + CurCell - Anchor);
          end;
        end;
      SCAN_RIGHT:
        begin
          if CurCellPart = 1 then
          begin
            if CurChannel < NepperRec.ChannelCount - 1 then
            begin
              CurCellPart := 0;
              Input.InputCursor := 1;
              Inc(CurChannel);
              RenderInstrument;
            end;
          end else
          begin
            CurCellPart := 1;
          end;
          Screen.SetCursorPosition(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE) + (CurCellPart * 3), PATTERN_SCREEN_START_Y + CurCell - Anchor);
        end;
      SCAN_DOWN:
        begin
          MoveDown(1);
        end;
      SCAN_UP:
        begin
          MoveUp(1);
        end;
      SCAN_PGDN:
        begin
          MoveDown(4);
        end;
      SCAN_PGUP:
        begin
          MoveUp(4);
        end;
      SCAN_SPACE:
        begin
          if not IsPlaying then
            Player.Start(CurPatternIndex)
          else
            Player.Stop;
        end
      else
        case KBInput.CharCode of
          '+':
            begin
              if CurPatternIndex < High(Formats.Patterns) then
              begin
                Inc(CurPatternIndex);
                CurPattern := Formats.Patterns[CurPatternIndex];
                RenderPatternInfo;
              end;
            end;
          '-':
            begin
              if CurPatternIndex > 0 then
              begin
                Dec(CurPatternIndex);
                CurPattern := Formats.Patterns[CurPatternIndex];
                RenderPatternInfo;
              end;
            end;
        end;
    end;
  end;
end;

procedure LoopEditOctave;
var
  PC: PNepperChannel;
begin  
  PC := @CurPattern^[CurChannel];
  case KBInput.CharCode of
    ')':
      begin
        CurOctave := 0;
        RenderOctave;
      end;
    '!':
      begin
        CurOctave := 1;
        RenderOctave;
      end;
    '@':
      begin
        CurOctave := 2;
        RenderOctave;
      end;
    '#':
      begin
        CurOctave := 3;
        RenderOctave;
      end;
    '$':
      begin
        CurOctave := 4;
        RenderOctave;
      end;
    '%':
      begin
        CurOctave := 5;
        RenderOctave;
      end;
    '^':
      begin
        CurOctave := 6;
        RenderOctave;
      end;
    '<':
      begin
        if PC^.InstrumentIndex > 0 then
        begin
          Dec(PC^.InstrumentIndex);
          RenderInstrument;
          Adlib.SetInstrument(CurChannel, @NepperRec.Instruments[PC^.InstrumentIndex]);
        end;
      end;
    '>':
      begin
        if PC^.InstrumentIndex < 31 then
        begin
          Inc(PC^.InstrumentIndex);
          RenderInstrument;
          Adlib.SetInstrument(CurChannel, @NepperRec.Instruments[PC^.InstrumentIndex]);
        end;
      end;
  end;
end;

procedure LoopEditStep;
begin
  case KBInput.ScanCode of
    SCAN_UP:
      begin
        if CurStep < 9 then
        begin
          Inc(CurStep);
          RenderStep;
        end;
      end;        
    SCAN_DOWN:
      begin
        if CurStep > 0 then
        begin
          Dec(CurStep);
          RenderStep;
        end;
      end;
  end;
end;

procedure Loop;
begin
  ResetParams;
  RenderTexts; 
  Screen.SetCursorPosition(PATTERN_SCREEN_START_X + (CurChannel * PATTERN_CHANNEL_WIDE), PATTERN_SCREEN_START_Y + CurCell - Anchor);
  repeat
    Keyboard.WaitForInput;
    if Keyboard.IsShift then
    begin
      LoopEditOctave;  
      LoopEditStep;
    end else
    begin
      LoopEditPattern;
      case KBInput.ScanCode of
        SCAN_ENTER:
          begin
            IsEditMode := not IsEditMode;
            RenderEditModeText;
          end;
      end;
    end;
  until (KBInput.ScanCode = SCAN_ESC) or (KBInput.ScanCode = SCAN_F3) or (KBInput.ScanCode = SCAN_TAB);
  if KBInput.ScanCode = SCAN_TAB then
  begin
    ResetParams;
  end;
end;

initialization
  VirtualSheetPointer := AllocMem(80*64*2);
  CurPattern := Formats.Patterns[0];
  CurPatternIndex := 0;  
  GS3[0] := Char(3);
  GS2[0] := Char(2);

finalization
  Freemem(VirtualSheetPointer);

end.

