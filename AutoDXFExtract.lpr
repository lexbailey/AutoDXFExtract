program AutoDXFExtract;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  { you can add units after this }
  {$IFDEF XMLVersionLaz2}
  laz2_XMLRead, laz2_XMLWrite, laz2_DOM,
  {$ELSE}
  XMLRead, XMLWrite, DOM
  {$endif}
  ;

type

  { TAutoDXFExtract }

  TAutoDXFExtract = class(TCustomApplication)
  protected
    fFile: TXMLDocument;
    fFileName: string;
    fFileValid: boolean;
    procedure DoRun; override;
    procedure XMLErrorHandler(E: EXMLReadError);
    function getLayer(id: integer): TDOMNode;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TAutoDXFExtract }

function ExtractFileNameEX(const AFileName:String): String;
 var
   I: integer;
 begin
    I := LastDelimiter('.'+PathDelim+DriveDelim,AFileName);
        if (I=0)  or  (AFileName[I] <> '.')
            then
                 I := MaxInt;
          Result := ExtractFileName(Copy(AFileName,1,I-1));
 end;

procedure TAutoDXFExtract.DoRun;
var
  ErrorMsg: String;
  Parser: TDOMParser;
  Src: TXMLInputSource;
  Input: TFileStream;
  i: integer;
  ThisLayer: TDOMNode;
  done: boolean;
  thisID, thisName: string;
  outFilePath: string;
  outfile: TextFile;
  allnames: string;
  groupType: string;
  justName: string;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('hio',['help','input','output']);
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h','help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }

  if not HasOption('i','input') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  if not HasOption('o','output') then begin
    WriteLn('Default output used "dxf_Makefile"');
    outFilePath := 'dxf_Makefile';
  end else
  begin
    outFilePath := GetOptionValue('o', 'output');
  end;


  AssignFile(outFile, outFilePath);
  Rewrite(outFile);  // creating the file

  fFileName := GetOptionValue('i', 'input');
  justName := ExtractFileNameEx(fFileName);
  if fileExists(fFileName) then
  begin
    try
      fFileValid := true;
      // create a parser object
      Parser := TDOMParser.Create;
      // get the actual file from disk
      Input := TFileStream.Create(fFileName, fmOpenRead);
      // create the input source
      Src := TXMLInputSource.Create(Input);
      // we want validation
      Parser.Options.Validate := True;
      // assign a error handler which will receive notifications
      Parser.OnError := @XMLErrorHandler;
      // now do the job
      Parser.Parse(Src, fFile);
    except
    end;
    Input.free;
    Parser.Free;
    Src.Free;
  end else begin
    WriteLn('Oh no, input file no good!');
    fFileValid := false;
    Terminate;
    Exit;
  end;

  //we have an input

  i := 0;
  done := false;
  WriteLn('Everything looks good, writing makefile to "', outFilePath, '"');
  allnames := '';
  repeat begin
    ThisLayer := getLayer(i);
    if Assigned(ThisLayer) then begin

      groupType := TDOMElement(ThisLayer).GetAttribute('inkscape:groupmode');

      if groupType = 'layer' then begin
            thisID := TDOMElement(ThisLayer).GetAttribute('id');
            thisName := TDOMElement(ThisLayer).GetAttribute('inkscape:label');
            WriteLn('Found layer "', thisID, '", Layer is "', thisName, '".');
            allnames := allnames + justname + '_' + thisName + '.dxf ';
            Writeln(outFile, '%_' + thisName + '.eps: ../svg_files/%.svg'  + #10+
           	#9+'inkscape -E $@ $< --export-id=' + thisID + #10 + #10);
      end;
    end else begin
      done := true;
    end;
    i := i+1;
  end until done;

  Writeln(outFile, '%.dxf: %.eps' +#10 +
	#9+'pstoedit -dt -f dxf:-polyaslines $< $@' +#10+#10);

  Writeln(outFile, 'all: ' + allnames);

  CloseFile(outFile);
  // stop program loop
  Terminate;
end;

procedure TAutoDXFExtract.XMLErrorHandler(E: EXMLReadError);
begin
  if (E.Severity = esError) or (E.Severity = esFatal) then
    fFileValid := false; //There was an error, file is no longer valid
end;

function TAutoDXFExtract.getLayer(id: integer): TDOMNode;
var layers: TDOMNodeList;
  layerExists : boolean;
begin
  layers := fFile.GetElementsByTagName('g');
  layerExists := layers.count > id;
  if layerExists then begin
     result := layers.Item[id];
  end else
  begin
      result := nil;
  end;
  layers.Free;
end;

constructor TAutoDXFExtract.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TAutoDXFExtract.Destroy;
begin
  inherited Destroy;
end;

procedure TAutoDXFExtract.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ',ExeName,' -i <input_file> -o <output_file>');
end;

var
  Application: TAutoDXFExtract;
begin
  Application:=TAutoDXFExtract.Create(nil);
  Application.Title:='AutoDXFExtract';
  Application.Run;
  Application.Free;
end.

