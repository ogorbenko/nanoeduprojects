unit SpectrDrawThread;

interface

uses
   Classes,windows,SysUtils,Globaltype,MLPC_APILib_TLB,
   {$IFDEF DEBUG}
   frDebug,
   {$ENDIF}
   Activex;

type
  TSpectrDrawThread = class(TThread)
  private
    { Private declarations }
     FlgLine:Boolean;
     bufsize:integer;
     CurrentP,newline:integer;
     PrevZ:single;
     n,dataoutcount,spectrdatacount,CurrentGraph:Integer;
     ElementSize:Integer;
     nElements,CurChElements:Integer;
     TempAquiData:TLine;
     TempAquiDataIT:TLine;
    procedure GetLineData;
    procedure DrawCurrentLine;
  protected
    procedure Execute; override;
 public
      constructor Create;
      destructor Destroy; override;
  end;
var  SpectrThread:TSpectrDrawThread;
     SpectrThreadActive:boolean;
implementation

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure SpectrDrawThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ SpectrDrawThread }

uses    CspmVar,GlobalVar, GlobalDCl,GlobalFunction, SioCSPM,frSpectroscopy;

procedure TSpectrDrawThread.Execute;
var flgLine,flgtestline:boolean;
    newpoints,pointsNmb:integer;
    CurrentPoint:integer;
    ds:integer;
    NewPCount,NPC:longint;
    i:dword;
     //NE II
    hr:HResult;
    flgEnd:boolean;
    NChElements,CurChElements,nRead:integer;
    ID:integer;
    data:integer;
  //  pstopval:Pinteger;
    errcnt:integer;
begin
  { Place thread code here }
  GetTimeNow(StartHour, startMin, StartSec, startMsec);
   flgLine:=false;
   newline:=0;
   flgtestline:=true;
   bufsize:=7;       //4
   PointsNmb:=2*SpectrParams.NPoints;  //7
   CurrentPoint:=0;
   CurrentP:=0;
   dataoutcount:=0;   spectrdatacount:=0;
   CurrentGraph:=0;
   SpectrParams.NewPoints:=0;
   PrevZ:=SpectrParams.StartP;
   ds:=1;
try
   {$IFDEF DEBUG}
         Formlog.memolog.Lines.add('Start Spectr drawing');
    {$ENDIF}
if CreateChannels(AlgParams.NChannels) then
 begin
  arPCChannel[ch_Data_out].Main.Get_Id(ID);  //data out channel
  if ID=ch_Data_OUT then
  begin
    flgEnd:=false;
    hr:=arPCChannel[ch_Data_out].Main.get_Geometry(NChElements,ElementSize);
       {$IFDEF DEBUG}
        if Failed(hr) then Formlog.memolog.Lines.add('error read geometry'+inttostr(nread)+'hr='+inttostr(hr));
         Formlog.memolog.Lines.add('Channel data; Elements='+inttostr(NChElements)+'size='+inttostr(ElementSize));
      {$ENDIF}
    CurChElements:=0;   // current of elements
    nread:=0;

  while (not Terminated) and (not flgEnd)  do
   begin
       nread:=AlgParams.NGetCountEvent;//1;
        sleep(10);
//      if FlgStopJava then
//         begin


            hr:=arPCChannel[ch_Draw_done].ChannelRead.Read(DoneBuf,nread);     //read stop channel  if stopbutton pressed  pStopval^=done
            {$IFDEF DEBUG}
             if Failed(hr) then
                  Formlog.memolog.Lines.add('error read stop channel'+inttostr(nread)+'hr='+inttostr(hr))
                  else
                 Formlog.memolog.Lines.add('read stop channel ='+inttostr(PIntegerArray(DoneBuf)[0])+' '+inttostr(nread));
            {$ENDIF}

           if PIntegerArray(DoneBuf)[0]=done then
            begin
              flgEnd:=true; //stop button press       stop scanning
              if flgCurrentUserLeveL=Demo then  break;
            end;
//         end;

       hr:=arPCChannel[ch_Data_out].ChannelRead.Get_Count(nread);     //get new data count
       {$IFDEF DEBUG}
        if Failed(hr) then Formlog.memolog.Lines.add('error get count data '+inttostr(nread)+'hr='+inttostr(hr))
                      else Formlog.memolog.Lines.add('spectrdraw data to read '+inttostr(nread));
       {$ENDIF}
    if nread >= 1 then
     begin
      hr:=arPCChannel[ch_Data_out].ChannelRead.Read(DataBuf,nread);    /// read data //nread is not number of elements ????
       {$IFDEF DEBUG}
        if Failed(hr) then Formlog.memolog.Lines.add('error read channel data '+inttostr(nread)+'hr='+inttostr(hr))
                      else Formlog.memolog.Lines.add('spectrdraw data has read '+inttostr(nread));
       {$ENDIF}
        if Failed(hr) then
                    begin
                      nread:=0;
                      inc(errcnt); //
                    end;
       if errcnt> 100  then
                 begin
                    flgEnd:=true;
                      {$IFDEF DEBUG}
                            Formlog.memolog.Lines.add('STOP : NMB of CHANNEL ERRORS =   '+inttostr(errcnt));
                      {$ENDIF}
                 end;
      NewPCount:=nread;

   if  (NewPCount>0) then
    begin
           n:=NewPCount;
           NewPCount:=0;
           TempAquiData:=nil;
           SetLength(TempAquiData,3*n);
           GetLineData;
           Synchronize(DrawCurrentLine);
           if spectrdatacount>=NChElements*ElementSize then FlgEnd:=true;
   end;// NewPpoint>0
  end; //nread>=1
   end; {while ScanCount}
    PostMessage(SpectrWnd.Handle,wm_ThreadDoneMsg,mScanning,0);
    ScanDone;
    FreeChannels;
  end; //channel out
 end;  //create channels
 finally
   if (not Terminated) then  Self.Terminate;
 end;{finally}
end;

procedure TSpectrDrawThread.GetLineData;
var dir,i,kt,mt:integer;
   fUAM:datatype;
   valueZ:datatype;
begin
  i:=0;
  kt:=CurrentP;
  dataoutcount:=0;
//  mt:=0;
//  if FlgCurrentUserLevel<>Demo then dataoutcount:=0;
  while (i<ElementSize*n) do          //3
  begin
     fUAM:=datatype(PIntegerArray(DataBuf)[i+dataoutcount]  shr 16);
     valueZ:=datatype(PIntegerArray(DataBuf)[i+1+dataoutcount] shr 16);
     dir:= datatype(PIntegerArray(DataBuf)[i+2+dataoutcount]);
     ScanData.AquiSpectr.Data[SpectrParams.CurrentLine,kt]:=fUAM;       //discrets
     ScanData.AquiSpectr.Data[SpectrParams.CurrentLine,kt+1]:= valueZ;
     TempAquiData[i]:=fUAM;
     TempAquiData[i+1]:=valueZ;
     TempAquiData[i+2]:=dir;
     inc(kt,2);
     inc(i,ElementSize);         //3
  end;
  inc(dataoutcount,ElementSize*n);      //3
  inc(spectrdatacount,ElementSize*n);
  CurrentP:=kt;
 end;


procedure TSpectrDrawThread.DrawCurrentLine;
var dir,i,k:integer;
value,z:single;
umstart:single;

begin
  umstart:=round( ScanData.AquiSpectr.Data[SpectrParams.CurrentLine,1]*SpectrWNd.ZStepMin);;
     i:=0;
(*    case Currentgraph of
  0: begin                 //red          landing   UAM
       SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Series);
       for k:=0 to (N-2) do
       begin
          Z:=TempAquiData[i+1]*SpectrWnd.ZStepMin;
          value:=TempAquiData[i]*SpectrWnd.StepValueMin;
          if ( Z<>PrevZ )then
          begin
           SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Series.AddXY(Z,Value);
           inc(SpectrParams.NewPoints);
          end;
          PrevZ:=Z;
          inc(i,2);
       end;
    end;
  1: begin
      SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series);
     for k:=0 to (N-2) do  //blue   landing     IT
       begin
          Z:=TempAquiData[i+1]*SpectrWnd.ZStepMin;
          value:=TempAquiData[i]*SpectrWnd.StepValueMin;
        if (Z>=SpectrParams.StartP) then SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series.AddXY(Z,Value);
          inc(i,2);
       end;
      end;
 else begin      //blue        rising
     (*  i:=i0;
       SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.next.Series);
       for k:=0 to (N-1) do
       begin
          Z:=TempAquiData[i+1]*SpectrWnd.ZStepMin;
          value:=TempAquiData[i]*SpectrWnd.StepValueMin;
          inc(i,2);
        if Z>=umstart then
         begin
           SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series.AddXY(Z,Value);//,'',seriesColor[j]);
         end
         else if not (flgCurrentUserLevel=Demo) then  SpectrWnd.lblwarning.Visible:=true;
        end;
        i:=i0;
       SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.next.Series);
        for k:=0 to (N-1) do
       begin
          Z:=TempAquiData[i+1]*SpectrWnd.ZStepMin;
          value:=TempAquiData[i]*SpectrWnd.StepValueMin;
          inc(i,2);
        if Z>=umstart then
         begin
           SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series.AddXY(Z,Value);//,'',seriesColor[j]);
         end
         else if not (flgCurrentUserLevel=Demo) then  SpectrWnd.lblwarning.Visible:=true;
        end;
            end;
    end; //case
    *)
 while i<3*n do
  begin
     value:=TempAquiData[i]*SpectrWnd.StepValueMin;
     Z:=TempAquiData[i+1]*SpectrWnd.ZStepMin;
     dir:=TempAquiData[i+2];
 //    if Z > SpectrParams.StartP then
     
   case dir of
1: begin
     SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Series);
     SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Series.AddXY(Z,Value);
     inc(SpectrParams.NewPoints);
    end;
-1: begin
     SpectrWnd.ArChart[SpectrParams.CurrentLine].SetActiveSeries(SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series);
     SpectrWnd.ArChart[SpectrParams.CurrentLine].HeadSeriesList.Next.Series.AddXY(Z,Value);
    end;
      end; //case
      inc(i,3);
  end;
end;

constructor TSpectrDrawThread.Create;
begin
  inherited Create(True);
    FreeOnTerminate:=true;
    Priority := TThreadPriority(tpNormal);
    Suspended := false;// Resume;
 end;

destructor TSpectrDrawThread.Destroy;
begin
   ThreadFlg:=mDrawing;
   PostMessage(SpectrWND.Handle,wm_ThreadDoneMsg,ThreadFlg,0);
   inherited destroy;
end;
end.
