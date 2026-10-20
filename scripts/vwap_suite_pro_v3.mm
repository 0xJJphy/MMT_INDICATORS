script "VWAP Suite Pro · Profiles & Naked Levels"
data chart=subscribe(data.ohlcv,history:3000)
setup a5=extend.right
setup K=extend.none
setup a4=linestyle.dotted
setup a0=linestyle.dashed
input(
input.tab(title:"General")
input.group(title:"Calculation")
ix0=input.select("HLC3",title:"Source",description:"4H approximates W/M/Q/Y; others: chart bars.",options:["HLC3","OHLC4","HL2","Close","HLC3 · 4H","OHLC4 · 4H","HL2 · 4H","Close · 4H"],key:"srcMode")
ix1=input.bool(true,title:"Break at reset",key:"cutOnReset")
input.group(title:"Band defaults · transparent = source",collapsible:true,collapsed:true)
ix2=input.select("Line + fill",title:"Band 1 ±σ",options:["Off","Line","Fill","Line + fill"],key:"globalBand1")
ix3=input.float(1,min:0.1,max:5,sameLine:true,key:"std1Mult")
std1Color=input.color(color.transparent,sameLine:true)
uShowStd2=input.bool(false,title:"Band 2 ±σ")
ix4=input.float(2,title:"σ2",min:0.1,max:5,sameLine:true,key:"std2Mult")
ix5=input.color(color.transparent,sameLine:true,key:"std2Color")
ix6=input.select("No fill",options:["No fill","Fill"],sameLine:true,key:"fmodeStd2")
uShowStd3=input.bool(false,title:"±3σ (periodic only)")
ix7=input.float(3,title:"σ3",min:0.1,max:5,sameLine:true,key:"std3Mult")
ix8=input.color(color.transparent,sameLine:true,key:"std3Color")
ix9=input.select("No fill",options:["No fill","Fill"],sameLine:true,key:"fmodeStd3")
fillOpacity=input.int(18,title:"Fill opacity %",min:0,max:100)
input.group(title:"Shared touch rules",collapsible:true,collapsed:true)
nakedTouch=input.select("Wick",title:"Touch by",options:["Wick","Body"])
ix10=input.bool(true,title:"Gaps invalidate levels",key:"nakedGapTouch")
nakedTolBps=input.float(2,title:"Tolerance (bps)",min:0,max:50)
nvMax=input.int(60,title:"Levels per engine",min:10,max:200)
input.group(title:"HUD (distance to VWAPs)")
ix11=input.bool(true,title:"Show HUD",key:"showHud")
hudPos=input.select("Bottom right",title:"Position",options:["Top right","Top left","Bottom right","Bottom left"],when:ix11)
hudSize=input.float(11,title:"Size",min:8,max:18,when:ix11)
input.group(title:"Alerts",collapsible:true,collapsed:true)
ix12=input.bool(true,title:"Enable alerts",description:"Off skips reference.",key:"enableAlerts")
ix13=input.select("Daily",title:"Reference VWAP",options:["4H","Daily","Weekly","Monthly","Quarterly","Yearly"],when:ix12,key:"alertPeriod")
alertAcrossReset=input.bool(false,title:"Allow crosses at period reset",when:ix12)
ix14=input.select("Every bar",title:"Band alert frequency",options:["Every bar","On entry"],when:ix12,key:"alertBandMode")
alertSigma=input.select("2σ",title:"Band extension",options:["1σ","2σ","3σ"],sameLine:true,when:ix12)
input.tab(title:"Periodic")
input.group(title:"VWAPs")
uShow4H=input.bool(false,title:"4H")
color4H=input.color(color.rgb(148,163,184),title:"4H style",sameLine:true,when:cb)
uPmode4H=input.select("No projection",options:["No projection","Project"],sameLine:true,when:cb)
uShowDaily=input.bool(true,title:"Daily")
colorDaily=input.color(color.rgb(227,179,65),title:"Daily style",sameLine:true,when:ce)
uPmodeDaily=input.select("No projection",options:["No projection","Project"],sameLine:true,when:ce)
uShowWeekly=input.bool(true,title:"Weekly")
colorWeekly=input.color(color.rgb(59,130,246),title:"Weekly style",sameLine:true,when:cf)
uPmodeWeekly=input.select("Project",options:["No projection","Project"],sameLine:true,when:cf)
uShowMonthly=input.bool(false,title:"Monthly")
colorMonthly=input.color(color.rgb(78,205,196),title:"Monthly style",sameLine:true,when:cg)
uPmodeMonthly=input.select("No projection",options:["No projection","Project"],sameLine:true,when:cg)
uShowQuarterly=input.bool(false,title:"Quarterly")
colorQuarterly=input.color(color.rgb(176,132,204),title:"Quarterly style",sameLine:true,when:ch)
uPmodeQuarterly=input.select("No projection",options:["No projection","Project"],sameLine:true,when:ch)
uShowYearly=input.bool(false,title:"Yearly")
colorYearly=input.color(color.rgb(249,115,22),title:"Yearly style",sameLine:true,when:ci)
uPmodeYearly=input.select("No projection",options:["No projection","Project"],sameLine:true,when:ci)
input.group(title:"Widths",collapsible:true,collapsed:true)
width4H=input.float(1.5,title:"4H",min:0.5,max:5,when:cb)
widthDaily=input.float(2,title:"Daily",min:0.5,max:5,when:ce)
widthWeekly=input.float(2,title:"Weekly",min:0.5,max:5,when:cf)
widthMonthly=input.float(2.5,title:"Monthly",min:0.5,max:5,when:cg)
widthQuarterly=input.float(2.5,title:"Quarterly",min:0.5,max:5,when:ch)
widthYearly=input.float(3,title:"Yearly",min:0.5,max:5,when:ci)
input.group(title:"Bands 1/2; 0 = General",collapsible:true,collapsed:true)
mode4H=input.select("No σ",title:"4H lines",description:"1/2: slots; third: General. σ modes: legacy.",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:cb)
zone4H=input.select("Global",title:"4H fill",description:"Center=±σ1; Between=σ1–σ2; Global=legacy.",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:cb)
mul4H1=input.float(1,title:"4H σ1",description:"0=General.",min:0,max:5,when:cb)
mul4H2=input.float(2,min:0,max:5,sameLine:true,when:cb)
uModeDaily=input.select("General",title:"Daily lines",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:ce)
zoneDaily=input.select("General",title:"Daily fill",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:ce)
mulDaily1=input.float(1,title:"Daily σ1",min:0,max:5,when:ce)
mulDaily2=input.float(2,min:0,max:5,sameLine:true,when:ce)
uModeWeekly=input.select("No σ",title:"Weekly lines",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:cf)
zoneWeekly=input.select("Global",title:"Weekly fill",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:cf)
mulWeekly1=input.float(1,title:"Weekly σ1",min:0,max:5,when:cf)
mulWeekly2=input.float(2,min:0,max:5,sameLine:true,when:cf)
uModeMonthly=input.select("No σ",title:"Monthly lines",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:cg)
ix15=input.select("Global",title:"Monthly fill",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:cg,key:"zoneMonthly")
mulMonthly1=input.float(1,title:"Monthly σ1",min:0,max:5,when:cg)
mulMonthly2=input.float(2,min:0,max:5,sameLine:true,when:cg)
uModeQuarterly=input.select("No σ",title:"Quarterly lines",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:ch)
ix16=input.select("Global",title:"Quarterly fill",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:ch,key:"zoneQuarterly")
mulQuarterly1=input.float(1,title:"Quarterly σ1",min:0,max:5,when:ch)
mulQuarterly2=input.float(2,min:0,max:5,sameLine:true,when:ch)
uModeYearly=input.select("No σ",title:"Yearly lines",options:["General","No σ","σ","σ + fill","1","1+2","1+2+3"],when:ci)
zoneYearly=input.select("Global",title:"Yearly fill",options:["General","Global","Off","Center","Between","Both","±3σ","Center+3","Between+3","All"],when:ci)
mulYearly1=input.float(1,title:"Yearly σ1",min:0,max:5,when:ci)
mulYearly2=input.float(2,min:0,max:5,sameLine:true,when:ci)
input.group(title:"Projections",collapsible:true,collapsed:true)
projCount=input.int(1,title:"Periods back",min:1,max:10)
ix17=input.bool(true,title:"Show in history",key:"projHistory")
projWidth=input.float(1,title:"Width · color",min:0.5,max:4)
ix18=input.color(color.withAlpha(color.rgb(139,144,168),18),description:"Opacity controls projected fill; default 7%.",sameLine:true,key:"projColor")
input.tab(title:"Rolling")
input.group(title:"Windows · days / color")
uShowRoll1=input.bool(false,title:"R1")
uRollDays1=input.float(7,title:"R1 days",min:0.1,max:365,sameLine:true,when:dg)
rollCol1=input.color(color.rgb(236,72,153),sameLine:true,when:dg)
uShowRoll2=input.bool(false,title:"R2")
ix19=input.float(30,min:0.1,max:365,sameLine:true,when:dh,key:"rollDays2")
rollCol2=input.color(color.rgb(245,158,11),sameLine:true,when:dh)
uShowRoll3=input.bool(false,title:"R3")
ix20=input.float(90,min:0.1,max:365,sameLine:true,when:di,key:"rollDays3")
rollCol3=input.color(color.rgb(196,181,253),sameLine:true,when:di)
input.group(title:"Bands 1/2; 0 = General",collapsible:true,collapsed:true)
uModeRoll1=input.select("No σ",title:"R1 lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:dg)
zoneRoll1=input.select("Global",title:"R1 fill",options:["General","Global","Off","Center","Between","Both"],when:dg)
mulRoll11=input.float(1,title:"R1 σ1",min:0,max:5,when:dg)
mulRoll12=input.float(2,min:0,max:5,sameLine:true,when:dg)
modeRoll2=input.select("No σ",title:"R2 lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:dh)
zoneRoll2=input.select("Global",title:"R2 fill",options:["General","Global","Off","Center","Between","Both"],when:dh)
mulRoll21=input.float(1,title:"R2 σ1",min:0,max:5,when:dh)
mulRoll22=input.float(2,min:0,max:5,sameLine:true,when:dh)
modeRoll3=input.select("No σ",title:"R3 lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:di)
zoneRoll3=input.select("Global",title:"R3 fill",options:["General","Global","Off","Center","Between","Both"],when:di)
mulRoll31=input.float(1,title:"R3 σ1",min:0,max:5,when:di)
mulRoll32=input.float(2,min:0,max:5,sameLine:true,when:di)
input.group(title:"Style")
ix21=input.float(1.5,title:"Width",min:0.5,max:5,key:"rollWidth")
input.group(title:"Band colors · transparent = rolling",collapsible:true,collapsed:true)
rollS1Col1=input.color(color.transparent,title:"R1 colors",when:ke)
rollS2Col1=input.color(color.transparent,sameLine:true,when:ke)
rollS1Col2=input.color(color.transparent,title:"R2 colors",when:kf)
rollS2Col2=input.color(color.transparent,sameLine:true,when:kf)
rollS1Col3=input.color(color.transparent,title:"R3 colors",when:kg)
rollS2Col3=input.color(color.transparent,sameLine:true,when:kg)
input.tab(title:"Sessions")
input.group(title:"Sessions · UTC")
uShowSessAsia=input.bool(false,title:"Asia")
ix22=input.color(color.rgb(255,183,77),sameLine:true,when:ec,key:"colSessAsia")
ix23=input.float(0,min:0,max:24,sameLine:true,when:jZ,key:"asiaStart")
asiaEnd=input.float(8,min:0,max:24,sameLine:true,when:jZ)
uShowSessLondon=input.bool(false,title:"London")
ix24=input.color(color.rgb(79,195,247),sameLine:true,when:dZ,key:"colSessLondon")
ix25=input.float(7,min:0,max:24,sameLine:true,when:ka,key:"londonStart")
londonEnd=input.float(15.5,min:0,max:24,sameLine:true,when:ka)
uShowSessNY=input.bool(false,title:"New York")
ix26=input.color(color.rgb(186,104,200),sameLine:true,when:ea,key:"colSessNY")
ix27=input.float(13.5,min:0,max:24,sameLine:true,when:kc,key:"nyStart")
nyEnd=input.float(20,min:0,max:24,sameLine:true,when:kc)
uShowSessClose=input.bool(false,title:"NY Close")
ix28=input.color(color.rgb(255,138,101),sameLine:true,when:eb,key:"colSessClose")
ix29=input.float(20,min:0,max:24,sameLine:true,when:kd,key:"closeStart")
closeEnd=input.float(24,min:0,max:24,sameLine:true,when:kd)
input.group(title:"Bands 1/2; 0 = General",collapsible:true,collapsed:true)
modeAsia=input.select("No σ",title:"Asia lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:ec)
zoneAsia=input.select("Global",title:"Asia fill",options:["General","Global","Off","Center","Between","Both"],when:ec)
mulAsia1=input.float(1,title:"Asia σ1",min:0,max:5,when:ec)
mulAsia2=input.float(2,min:0,max:5,sameLine:true,when:ec)
modeLondon=input.select("No σ",title:"London lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:dZ)
zoneLondon=input.select("Global",title:"London fill",options:["General","Global","Off","Center","Between","Both"],when:dZ)
mulLondon1=input.float(1,title:"London σ1",min:0,max:5,when:dZ)
mulLondon2=input.float(2,min:0,max:5,sameLine:true,when:dZ)
modeNY=input.select("No σ",title:"NY lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:ea)
zoneNY=input.select("Global",title:"NY fill",options:["General","Global","Off","Center","Between","Both"],when:ea)
mulNY1=input.float(1,title:"NY σ1",min:0,max:5,when:ea)
mulNY2=input.float(2,min:0,max:5,sameLine:true,when:ea)
modeClose=input.select("No σ",title:"Close lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:eb)
zoneClose=input.select("Global",title:"Close fill",options:["General","Global","Off","Center","Between","Both"],when:eb)
mulClose1=input.float(1,title:"Close σ1",min:0,max:5,when:eb)
mulClose2=input.float(2,min:0,max:5,sameLine:true,when:eb)
input.group(title:"Style")
ix30=input.float(1.5,title:"Width",min:0.5,max:5,key:"sessWidth")
extendSessVWAP=input.bool(true,title:"Extend previous session")
input.tab(title:"Anchored")
input.group(title:"High / Low")
ix31=input.bool(true,title:"Cur. M/Q/Y",key:"uEnableMonthAvwap")
ix32=input.color(color.rgb(239,83,80),sameLine:true,when:cY,key:"colMonthHigh")
ix33=input.color(color.rgb(102,187,106),sameLine:true,when:cY,key:"colMonthLow")
hlMP=input.select("Month",options:["Month","Quarter","Year"],sameLine:true)
ix34=input.bool(true,title:"Prev. M/Q/Y",key:"uEnablePrevMonthAvwap")
ix35=input.color(color.rgb(255,138,128),sameLine:true,when:cZ,key:"colPrevMonthHigh")
ix36=input.color(color.rgb(185,246,202),sameLine:true,when:cZ,key:"colPrevMonthLow")
uEnableWeekAvwap=input.bool(false,title:"Cur. W/Q/Y")
ix37=input.color(color.rgb(239,83,80),sameLine:true,when:db,key:"colWeekHigh")
ix38=input.color(color.rgb(102,187,106),sameLine:true,when:db,key:"colWeekLow")
hlWP=input.select("Week",options:["Week","Quarter","Year"],sameLine:true)
ix39=input.bool(false,title:"Prev. W/Q/Y",key:"uEnablePrevWeekAvwap")
ix40=input.color(color.rgb(255,138,128),sameLine:true,when:dc,key:"colPrevWeekHigh")
ix41=input.color(color.rgb(185,246,202),sameLine:true,when:dc,key:"colPrevWeekLow")
uEnableDayAvwap=input.bool(false,title:"Current day")
ix42=input.color(color.rgb(239,83,80),sameLine:true,when:de,key:"colDayHigh")
ix43=input.color(color.rgb(102,187,106),sameLine:true,when:de,key:"colDayLow")
ix44=input.bool(false,title:"Previous day",key:"uEnablePrevDayAvwap")
ix45=input.color(color.rgb(255,138,128),sameLine:true,when:df,key:"colPrevDayHigh")
ix46=input.color(color.rgb(185,246,202),sameLine:true,when:df,key:"colPrevDayLow")
input.group(title:"Bands 1/2; 0 = General",collapsible:true,collapsed:true)
modeMonth=input.select("No σ",title:"M/Q/Y lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:cY)
zoneMonth=input.select("Global",title:"M/Q/Y fill",options:["General","Global","Off","Center"],when:cY)
mulMonth1=input.float(1,title:"M/Q/Y σ1",min:0,max:5,when:cY)
mulMonth2=input.float(2,min:0,max:5,sameLine:true,when:cY)
ix47=input.select("No σ",title:"Prev M/Q/Y lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:cZ,key:"modePrevMonth")
ix48=input.select("Global",title:"Prev M/Q/Y fill",options:["General","Global","Off","Center"],when:cZ,key:"zonePrevMonth")
mulPrevMonth1=input.float(1,title:"Prev M/Q/Y σ1",min:0,max:5,when:cZ)
mulPrevMonth2=input.float(2,min:0,max:5,sameLine:true,when:cZ)
modeWeek=input.select("No σ",title:"W/Q/Y lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:db)
zoneWeek=input.select("Global",title:"W/Q/Y fill",options:["General","Global","Off","Center"],when:db)
mulWeek1=input.float(1,title:"W/Q/Y σ1",min:0,max:5,when:db)
mulWeek2=input.float(2,min:0,max:5,sameLine:true,when:db)
ix49=input.select("No σ",title:"Prev W/Q/Y lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:dc,key:"modePrevWeek")
ix50=input.select("Global",title:"Prev W/Q/Y fill",options:["General","Global","Off","Center"],when:dc,key:"zonePrevWeek")
mulPrevWeek1=input.float(1,title:"Prev W/Q/Y σ1",min:0,max:5,when:dc)
mulPrevWeek2=input.float(2,min:0,max:5,sameLine:true,when:dc)
modeDay=input.select("No σ",title:"D lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:de)
zoneDay=input.select("Global",title:"Daily fill",options:["General","Global","Off","Center"],when:de)
mulDay1=input.float(1,title:"Daily σ1",min:0,max:5,when:de)
mulDay2=input.float(2,min:0,max:5,sameLine:true,when:de)
ix51=input.select("No σ",title:"pD lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:df,key:"modePrevDay")
ix52=input.select("Global",title:"pD fill",options:["General","Global","Off","Center"],when:df,key:"zonePrevDay")
mulPrevDay1=input.float(1,title:"pD σ1",min:0,max:5,when:df)
mulPrevDay2=input.float(2,min:0,max:5,sameLine:true,when:df)
input.group(title:"Advanced",collapsible:true,collapsed:true)
ptPrevMode=input.select("Until touched",title:"Previous until",options:["Until touched","Until new period"])
ptHideOld=input.bool(true,title:"Hide replaced anchors")
ptPivotMode=input.select("Wick (high / low)",title:"Anchor by",description:"VWAP uses Source.",options:["Wick (high / low)","Close"])
input.group(title:"Date-anchored AVWAP (UTC)")
ix53=input.bool(false,title:"Enable",description:"*=anchor before history.",key:"enableCustomAvwap")
ix54=input.color(color.rgb(255,215,0),sameLine:true,when:bv,key:"colCustomAvwap")
customYear=input.int(2026,title:"Year · month · day · hour",min:2009,max:2100,when:bv)
customMonth=input.int(1,title:"Month",min:1,max:12,sameLine:true,when:bv)
customDay=input.int(1,title:"Day",min:1,max:31,sameLine:true,when:bv)
customHour=input.int(0,title:"Hour",min:0,max:23,sameLine:true,when:bv)
input.group(title:"Date bands · 0 inherits",collapsible:true,collapsed:true)
modeCustom=input.select("No σ",title:"Custom lines",options:["General","No σ","σ","σ + fill","1","1+2"],when:bv)
zoneCustom=input.select("Global",title:"Custom fill",options:["General","Global","Off","Center","Between","Both"],when:bv)
mulCustom1=input.float(1,title:"Custom σ1",min:0,max:5,when:bv)
mulCustom2=input.float(2,min:0,max:5,sameLine:true,when:bv)
input.tab(title:"Naked VWAP")
input.group(title:"Detection")
uShowNaked=input.bool(true,title:"Enable VWAP nakeds")
uNakedOnlyMode=input.bool(false,title:"Hide periodic VWAP curves",when:q)
input.group(title:"Types",collapsible:true,collapsed:true)
uNk4H=input.bool(false,title:"4H",when:q)
uNkD=input.bool(true,title:"Daily",when:q)
uNkW=input.bool(true,title:"Weekly",when:q)
uNkM=input.bool(true,title:"Monthly",when:q)
uNkQ=input.bool(false,title:"Quarterly",when:q)
uNkY=input.bool(false,title:"Yearly",when:q)
uNkAsia=input.bool(false,title:"Asia",when:q)
uNkLondon=input.bool(false,title:"London",when:q)
uNkNY=input.bool(false,title:"New York",when:q)
uNkClose=input.bool(false,title:"NY close",when:q)
uNkAnchM=input.bool(false,title:"M/Q/Y H/L",when:q)
uNkAnchW=input.bool(false,title:"W/Q/Y H/L",when:q)
uNkAnchD=input.bool(false,title:"Day H/L",when:q)
input.group(title:"Naked history",collapsible:true,collapsed:true)
nkSessMode=input.select("Any touch",title:"Session nakeds invalidated by",options:["Any touch","Same session only"],when:q)
ix55=input.bool(true,title:"Show touched VWAP nakeds",when:q,key:"nvShowTouched")
nvHistMode=input.select("By score",title:"Touched style",options:["By score","Gray"],when:gU)
nvHistMax=input.int(300,title:"Max touched in history",min:10,max:2000,when:gU)
ix56=input.bool(true,title:"Score at the touch point",when:gU,key:"nvHistLabel")
input.group(title:"Naked bands")
ix57=input.select("Off",title:"Bands",options:["Off","±1σ","±1σ ±2σ"],when:q,key:"nvStdMode")
ix58=input.bool(true,title:"Extend naked σ right",when:q&&ix57 !="Off",key:"nvStdExtend")
input.group(title:"Style & labels",collapsible:true,collapsed:true)
ix59=input.select("Dotted",title:"Line · width",options:["Dotted","Dashed","Solid","Faint tail","Faint tail + levels"],when:ag,key:"nvLineStyle")
ix60=input.float(0.9,min:0.5,max:5,sameLine:true,when:ag,key:"nvLineWidth")
ix61=input.bool(true,title:"Extend naked VWAPs right",when:ag,key:"nvExtend")
ix62=input.select("Clean + axis",title:"Label · size",options:["Axis","Axis + Origin","Right margin","Origin","None","Clean right","Clean + axis","Clean + date","Clean + axis + date"],when:ag,key:"nvTagPos")
ix63=input.float(11,min:8,max:48,sameLine:true,when:ag,key:"nvBadgeSize")
ix64=input.int(0,title:"Axis · 0=All (48)",min:0,max:3,when:ag,key:"nvAxisSlots")
nvDim=input.bool(true,title:"Dim the non-nearest",when:ag)
nvDimPct=input.int(25,title:"Dimmed opacity %",min:0,max:100,when:nvDim)
ix65=input.bool(true,title:"Price",when:ag,key:"showNvPrice")
showScores=input.bool(true,title:"Score",when:ag)
nvOffsetBps=input.float(8,title:"Label lift (bps)",min:0,max:50,when:ag)
nvCol4H=input.color(color.transparent,title:"Colors · transparent = source",when:ag)
nvColD=input.color(color.transparent,sameLine:true,when:ag)
nvColW=input.color(color.transparent,sameLine:true,when:ag)
nvColM=input.color(color.transparent,sameLine:true,when:ag)
nvColQ=input.color(color.transparent,sameLine:true,when:ag)
nvColY=input.color(color.transparent,sameLine:true,when:ag)
input.group(title:"Score",collapsible:true,collapsed:true)
ix66=input.select("R",title:"Display",options:["R","R + V","R + V + Δ"],when:ag,key:"nvScoreMode")
nvScoreN=input.int(14,title:"Window (periods of the same type)",min:5,max:50,when:ag)
nvWVol=input.float(0.7,title:"Volume weight · Δ weight",min:0,max:1,when:ag)
nvWDelta=input.float(0.3,min:0,max:1,sameLine:true,when:ag)
nvScoreByDelta=input.bool(false,title:"Score color by Δ sign",when:ag)
input.tab(title:"Profiles")
input.group(title:"VPOC / TPOC · one shared period")
ix67=input.select("Daily",title:"Period",options:["4H","Daily","Weekly","Monthly","Quarterly","Yearly"],when:cc,key:"pfPeriod",description:"Q/Y: from 1D candles.")
pfView=input.select("Current",title:"View",options:["Current","Previous","Both"],sameLine:true,when:cc)
ix68=input.select("Both",title:"Profile",options:["Off","VPOC","TPOC","Both"],description:"Confirmed; *=partial; TPOC=visits/block.",key:"pfMode")
ix69=input.select("Both",title:"Naked",options:["Off","VPOC","TPOC","Both"],sameLine:true,key:"pfNkMode")
ix70=input.select("Off",title:"Value area",options:["Off","Volume","TPO","Both"],key:"pfVaMode")
pfVaPct=input.float(70,title:"%",min:1,max:100,sameLine:true,when:kh)
pfVaFill=input.bool(false,title:"Fill",sameLine:true,when:kh)
pfRankHud=input.bool(true,title:"Volume percentile in HUD",description:"Confirmed volume %≤price; *=partial; not predictive.")
ix71=input.bool(false,title:"Hide touched VPOC/TPOC",when:ix69 !="Off",description:"Off: 300 touched. Shared rules; aligned/full periods.",key:"pfNkOnlyLive")
input.group(title:"Style")
pfVColor=input.color(color.rgb(255,193,7),title:"VPOC / TPOC",when:cc)
ix72=input.color(color.rgb(171,120,235),sameLine:true,when:cc,key:"pfTColor")
ix73=input.float(1.2,title:"Width",min:0.5,max:3,sameLine:true,when:cc,key:"pfWidth")
input.group(title:"Resolution",collapsible:true,collapsed:true)
pfBlock=input.select("30m",title:"Time block",options:["15m","30m","1h"],when:cc)
pfTicks=input.int(0,title:"Row size · ticks",min:0,max:1000000,when:cc,description:"0=4 bins (Q/Y: 0.2%); ties=lower; 250 blocks; *=partial.")
)
setup(
lB=ix2=="Line"||ix2=="Line + fill"
ja=ix2=="Fill"||ix2=="Line + fill"?"Fill":"No fill"
lC=uShowStd2
lD=uShowStd3
ba=uShow4H
bb=uShowDaily
bg=uShowWeekly
bd=uShowMonthly
bf=uShowQuarterly
bh=uShowYearly
ki=uModeDaily
km=uModeWeekly
kj=uModeMonthly
kk=uModeQuarterly
kn=uModeYearly
mX=uPmode4H
mY=uPmodeDaily
nb=uPmodeWeekly
mZ=uPmodeMonthly
na=uPmodeQuarterly
nc=uPmodeYearly
es=uShowSessAsia
eu=uShowSessLondon
ev=uShowSessNY
et=uShowSessClose
aO=ix31
bT=ix34
aH=uEnableWeekAvwap
bU=ix39
aG=uEnableDayAvwap
bS=ix44
q=uShowNaked
mE=uNakedOnlyMode
kx=uNk4H
ky=uNkD
kB=uNkW
kz=uNkM
kA=uNkQ
kC=uNkY
hh=uNkAsia
hk=uNkLondon
hl=uNkNY
hj=uNkClose
hf=uNkAnchM
hg=uNkAnchW
he=uNkAnchD
cC=uShowRoll1
cD=uShowRoll2
cE=uShowRoll3
ie=uRollDays1
kl=uModeRoll1
ac=Qm{one:false,two:false,three:false,active:false}
ad=Qh{center:false,ring:false,outer:false,filled:false}
gz=Qm{one:lB,two:lC,three:lD,active:lB||lC||lD}
ah={"General":gz,"No σ":ac,"σ":gz,"σ + fill":gz,"1":Qm{one:true,two:false,three:false,active:true},"1+2":Qm{one:true,two:true,three:false,active:true},"1+2+3":Qm{one:true,two:true,three:true,active:true}}
jb=Qh{center:ja=="Fill",ring:ix6=="Fill",outer:ix9=="Fill",filled:ja=="Fill"||ix6=="Fill"||ix9=="Fill"}
ai={"General":jb,"Global":jb,"Off":ad,"Center":Qh{center:true,ring:false,outer:false,filled:true},"Between":Qh{center:false,ring:true,outer:false,filled:true},"Both":Qh{center:true,ring:true,outer:false,filled:true},"±3σ":Qh{center:false,ring:false,outer:true,filled:true},"Center+3":Qh{center:true,ring:false,outer:true,filled:true},"Between+3":Qh{center:false,ring:true,outer:true,filled:true},"All":Qh{center:true,ring:true,outer:true,filled:true}}
bs4H=Qc{l:ah.get(mode4H)??ac,z:ai.get(zone4H=="Global"&&mode4H !="σ + fill"?"Off":zone4H)??ad,m1:mul4H1>0.0?mul4H1:ix3,m2:mul4H2>0.0?mul4H2:ix4}
bsDaily=Qc{l:ah.get(ki)??ac,z:ai.get(zoneDaily=="Global"&&ki !="σ + fill"?"Off":zoneDaily)??ad,m1:mulDaily1>0.0?mulDaily1:ix3,m2:mulDaily2>0.0?mulDaily2:ix4}
bsWeekly=Qc{l:ah.get(km)??ac,z:ai.get(zoneWeekly=="Global"&&km !="σ + fill"?"Off":zoneWeekly)??ad,m1:mulWeekly1>0.0?mulWeekly1:ix3,m2:mulWeekly2>0.0?mulWeekly2:ix4}
bsMonthly=Qc{l:ah.get(kj)??ac,z:ai.get(ix15=="Global"&&kj !="σ + fill"?"Off":ix15)??ad,m1:mulMonthly1>0.0?mulMonthly1:ix3,m2:mulMonthly2>0.0?mulMonthly2:ix4}
bsQuarterly=Qc{l:ah.get(kk)??ac,z:ai.get(ix16=="Global"&&kk !="σ + fill"?"Off":ix16)??ad,m1:mulQuarterly1>0.0?mulQuarterly1:ix3,m2:mulQuarterly2>0.0?mulQuarterly2:ix4}
bs=Qc{l:ah.get(kn)??ac,z:ai.get(zoneYearly=="Global"&&kn !="σ + fill"?"Off":zoneYearly)??ad,m1:mulYearly1>0.0?mulYearly1:ix3,m2:mulYearly2>0.0?mulYearly2:ix4}
gh=Qc{l:ah.get(modeAsia)??ac,z:ai.get(zoneAsia=="Global"&&modeAsia !="σ + fill"?"Off":zoneAsia)??ad,m1:mulAsia1>0.0?mulAsia1:ix3,m2:mulAsia2>0.0?mulAsia2:ix4}
gk=Qc{l:ah.get(modeLondon)??ac,z:ai.get(zoneLondon=="Global"&&modeLondon !="σ + fill"?"Off":zoneLondon)??ad,m1:mulLondon1>0.0?mulLondon1:ix3,m2:mulLondon2>0.0?mulLondon2:ix4}
gl=Qc{l:ah.get(modeNY)??ac,z:ai.get(zoneNY=="Global"&&modeNY !="σ + fill"?"Off":zoneNY)??ad,m1:mulNY1>0.0?mulNY1:ix3,m2:mulNY2>0.0?mulNY2:ix4}
gi=Qc{l:ah.get(modeClose)??ac,z:ai.get(zoneClose=="Global"&&modeClose !="σ + fill"?"Off":zoneClose)??ad,m1:mulClose1>0.0?mulClose1:ix3,m2:mulClose2>0.0?mulClose2:ix4}
bj=Qc{l:ah.get(modeMonth)??ac,z:ai.get(zoneMonth=="Global"&&modeMonth !="σ + fill"?"Off":zoneMonth)??ad,m1:mulMonth1>0.0?mulMonth1:ix3,m2:mulMonth2>0.0?mulMonth2:ix4}
eD=Qc{l:ah.get(ix47)??ac,z:ai.get(ix48=="Global"&&ix47 !="σ + fill"?"Off":ix48)??ad,m1:mulPrevMonth1>0.0?mulPrevMonth1:ix3,m2:mulPrevMonth2>0.0?mulPrevMonth2:ix4}
bk=Qc{l:ah.get(modeWeek)??ac,z:ai.get(zoneWeek=="Global"&&modeWeek !="σ + fill"?"Off":zoneWeek)??ad,m1:mulWeek1>0.0?mulWeek1:ix3,m2:mulWeek2>0.0?mulWeek2:ix4}
eE=Qc{l:ah.get(ix49)??ac,z:ai.get(ix50=="Global"&&ix49 !="σ + fill"?"Off":ix50)??ad,m1:mulPrevWeek1>0.0?mulPrevWeek1:ix3,m2:mulPrevWeek2>0.0?mulPrevWeek2:ix4}
bi=Qc{l:ah.get(modeDay)??ac,z:ai.get(zoneDay=="Global"&&modeDay !="σ + fill"?"Off":zoneDay)??ad,m1:mulDay1>0.0?mulDay1:ix3,m2:mulDay2>0.0?mulDay2:ix4}
eC=Qc{l:ah.get(ix51)??ac,z:ai.get(ix52=="Global"&&ix51 !="σ + fill"?"Off":ix52)??ad,m1:mulPrevDay1>0.0?mulPrevDay1:ix3,m2:mulPrevDay2>0.0?mulPrevDay2:ix4}
gj=Qc{l:ah.get(modeCustom)??ac,z:ai.get(zoneCustom=="Global"&&modeCustom !="σ + fill"?"Off":zoneCustom)??ad,m1:mulCustom1>0.0?mulCustom1:ix3,m2:mulCustom2>0.0?mulCustom2:ix4}
gm=Qc{l:ah.get(kl)??ac,z:ai.get(zoneRoll1=="Global"&&kl !="σ + fill"?"Off":zoneRoll1)??ad,m1:mulRoll11>0.0?mulRoll11:ix3,m2:mulRoll12>0.0?mulRoll12:ix4}
gn=Qc{l:ah.get(modeRoll2)??ac,z:ai.get(zoneRoll2=="Global"&&modeRoll2 !="σ + fill"?"Off":zoneRoll2)??ad,m1:mulRoll21>0.0?mulRoll21:ix3,m2:mulRoll22>0.0?mulRoll22:ix4}
gp=Qc{l:ah.get(modeRoll3)??ac,z:ai.get(zoneRoll3=="Global"&&modeRoll3 !="σ + fill"?"Off":zoneRoll3)??ad,m1:mulRoll31>0.0?mulRoll31:ix3,m2:mulRoll32>0.0?mulRoll32:ix4}
iy=(bs4H.l.active||bs4H.z.filled)
iB=(bsDaily.l.active||bsDaily.z.filled)
iG=(bsWeekly.l.active||bsWeekly.z.filled)
iD=(bsMonthly.l.active||bsMonthly.z.filled)
iF=(bsQuarterly.l.active||bsQuarterly.z.filled)
iH=(bs.l.active||bs.z.filled)
iz=(gh.l.active||gh.z.filled)
iC=(gk.l.active||gk.z.filled)
iE=(gl.l.active||gl.z.filled)
iA=(gi.l.active||gi.z.filled)
fV=(bj.l.active||bj.z.filled)
fX=(eD.l.active||eD.z.filled)
gc=(bk.l.active||bk.z.filled)
fY=(eE.l.active||eE.z.filled)
fU=(bi.l.active||bi.z.filled)
fW=(eC.l.active||eC.z.filled)
fZ=(gm.l.active||gm.z.filled)
ga=(gn.l.active||gn.z.filled)
gb=(gp.l.active||gp.z.filled)
iQ=(gj.l.active||gj.z.filled)
eg=mX=="Project"
ei=mY=="Project"
em=nb=="Project"
ej=mZ=="Project"
ek=na=="Project"
eo=nc=="Project"
co=q&&kx
mG=ba||co||(ix12&&ix13=="4H")
lY=(ba&&(ix11||iy))||(co&&ix57 !="Off")||(ix12&&ix13=="4H")
cu=q&&ky
mK=bb||cu||(ix12&&ix13=="Daily")
ma=(bb&&(ix11||iB))||(cu&&ix57 !="Off")||(ix12&&ix13=="Daily")
cA=q&&kB
gY=bg||cA||(ix12&&ix13=="Weekly")
iV=(bg&&(ix11||iG))||(cA&&ix57 !="Off")||(ix12&&ix13=="Weekly")
cx=q&&kz
gW=bd||cx||(ix12&&ix13=="Monthly")
iT=(bd&&(ix11||iD))||(cx&&ix57 !="Off")||(ix12&&ix13=="Monthly")
cz=q&&kA
gX=bf||cz||(ix12&&ix13=="Quarterly")
iU=(bf&&(ix11||iF))||(cz&&ix57 !="Off")||(ix12&&ix13=="Quarterly")
cB=q&&kC
gZ=bh||cB||(ix12&&ix13=="Yearly")
iW=(bh&&(ix11||iH))||(cB&&ix57 !="Off")||(ix12&&ix13=="Yearly")
cq=q&&hf
mI=aO||bT||cq
cM=(aO&&fV)||(bT&&fX)||(cq&&ix57 !="Off")
cr=q&&hg
mJ=aH||bU||cr
cO=(aH&&gc)||(bU&&fY)||(cr&&ix57 !="Off")
cp=q&&he
mH=aG||bS||cp
cL=(aG&&fU)||(bS&&fW)||(cp&&ix57 !="Off")
cs=q&&hh
kq=es||cs
eI=(es&&iz)||(cs&&ix57 !="Off")
cw=q&&hk
kt=eu||cw
eK=(eu&&iC)||(cw&&ix57 !="Off")
cy=q&&hl
ku=ev||cy
eL=(ev&&iE)||(cy&&ix57 !="Off")
ct=q&&hj
kr=et||ct
eJ=(et&&iA)||(ct&&ix57 !="Off")
mL=co||cu||cA||cx||cz||cB||cq||cr||cp||cs||cw||cy||ct
lZ=ix53&&(ix11||iQ)
gu=cC&&fZ
gv=cD&&ga
gw=cE&&gb
mM=cM||cO||cL||eI||eK||eL||eJ||gu||gv||gw
E=int(math.round(float(fillOpacity)*2.55))??46
iR=color.withAlpha(color.gray,90)
jc=!ix55
eU=nvHistMode=="By score"
invisible=color.withAlpha(color.white,0)
aD=int(math.round(float(E)*0.6))??28
bC=ptPrevMode=="Until touched"
lg=ptPivotMode=="Close"
fe=(aO?1:0)+(aH?1:0)+(aG?1:0)
ap=ptHideOld&&fe>0
lvSlots=ap?(aG?1536:(aH?1024:512)):1
lvLpsM=1+((bj.l.one||bj.z.center)?2:0)+(bj.l.two?2:0)
lvLpsW=1+((bk.l.one||bk.z.center)?2:0)+(bk.l.two?2:0)
lvLpsD=1+((bi.l.one||bi.z.center)?2:0)+(bi.l.two?2:0)
mB=math.max(aO?lvLpsM:1,math.max(aH?lvLpsW:1,aG?lvLpsD:1))
jR=math.min(200,math.max(24,int(math.floor(900.0/float(2*math.max(1,fe)*mB)))??24))
eZ=jR+12
dP=bT&&!aO
dR=bU&&!aH
dO=bS&&!aG
lf=(ba&&eg)||(bb&&ei)||(bg&&em)||(bd&&ej)||(bf&&ek)||(bh&&eo)
le=(ba&&eg&&(bs4H.z.center||bs4H.z.ring))||(bb&&ei&&(bsDaily.z.center||bsDaily.z.ring))||(bg&&em&&(bsWeekly.z.center||bsWeekly.z.ring))||(bd&&ej&&(bsMonthly.z.center||bsMonthly.z.ring))||(bf&&ek&&(bsQuarterly.z.center||bsQuarterly.z.ring))||(bh&&eo&&(bs.z.center||bs.z.ring))
mx=ap&&((aO&&bj.z.center)||(aH&&bk.z.center)||(aG&&bi.z.center))
eY=ix59=="Faint tail + levels"
dl=ix61&&(ix59=="Faint tail"||eY)
mP=ix61&&!dl?a5:K
mO=ix58?a5:K
dt=ix0=="HLC3"||ix0=="HLC3 · 4H"?0:(ix0=="OHLC4"||ix0=="OHLC4 · 4H"?1:(ix0=="HL2"||ix0=="HL2 · 4H"?2:3))
ih=time.sessionMinutes(int(math.round(ix23*60.0))??0,int(math.round(asiaEnd*60.0))??480)
ij=time.sessionMinutes(int(math.round(ix25*60.0))??420,int(math.round(londonEnd*60.0))??930)
ik=time.sessionMinutes(int(math.round(ix27*60.0))??810,int(math.round(nyEnd*60.0))??1200)
ii=time.sessionMinutes(int(math.round(ix29*60.0))??1200,int(math.round(closeEnd*60.0))??1440)
aM=math.max(1,time.tfSeconds(context.timeframe))
lq=math.max(1.0,ie*86400.0/float(aM))
ls=math.max(1.0,ix19*86400.0/float(aM))
lt=math.max(1.0,ix20*86400.0/float(aM))
lm=math.max(1,int(math.ceil(lq/4998.0))??1)
ln=math.max(1,int(math.ceil(ls/4998.0))??1)
lp=math.max(1,int(math.ceil(lt/4998.0))??1)
np=time.tfFromSeconds(aM*lm)
nq=time.tfFromSeconds(aM*ln)
nr=time.tfFromSeconds(aM*lp)
rollCap1=math.max(2,math.min(5000,(int(math.ceil(lq/float(lm)))??2)+1))
rollCap2=math.max(2,math.min(5000,(int(math.ceil(ls/float(ln)))??2)+1))
rollCap3=math.max(2,math.min(5000,(int(math.ceil(lt/float(lp)))??2)+1))
nk=math.max(1,int(math.round(ie*86400.0))??1)
ns=str.format("Rolling VWAP {0}D",ie)
nm=math.max(1,int(math.round(ix19*86400.0))??1)
nu=str.format("Rolling VWAP {0}D",ix19)
nn=math.max(1,int(math.round(ix20*86400.0))??1)
nw=str.format("Rolling VWAP {0}D",ix20)
gs=customYear*1000000+customMonth*10000+customDay*100+customHour
mS=ix59=="Solid"?linestyle.solid:(ix59 !="Dashed"?a4:a0)
bo=ix62=="Clean + axis"||ix62=="Clean + axis + date"
dj=bo&&ix64==0
nvAxisCount=dj?48:ix64==0?2:ix64
hn=ix62=="Clean + date"||ix62=="Clean + axis + date"
aq=ix62=="Axis"||ix62=="Axis + Origin"||(bo&&ix65)
ak=ix62=="Clean right"||bo||hn
ho=ix62=="Right margin"
hr=ix62=="Origin"||ix62=="Axis + Origin"
nQ=aq&&showScores
fT=nakedTouch=="Body"
fS=nakedTolBps/10000.0
gE=1.0+(ak?0.0:nvOffsetBps)/10000.0
nvStd1On=ix57 !="Off"
kF=ix57=="±1σ ±2σ"
kE=dl||!ix61||(nvStd1On&&!ix58)
nA=nkSessMode=="Same session only"
kD=int(math.round(float(nvDimPct)*2.55))??64
gB=hudPos=="Top right"||hudPos=="Bottom right"
jH=hudPos=="Top right"||hudPos=="Top left"
mk=gB?"right":"left"
ml=hudSize*1.55
iv=ix13=="4H"?bs4H:(ix13=="Daily"?bsDaily:(ix13=="Weekly"?bsWeekly:(ix13=="Monthly"?bsMonthly:(ix13=="Quarterly"?bsQuarterly:bs))))
eA=alertSigma=="1σ"?iv.m1:(alertSigma=="2σ"?iv.m2:ix7)
)
setup cb=ba
setup ce=bb
setup cf=bg
setup cg=bd
setup ch=bf
setup ci=bh
setup ec=es
setup jZ=es||(q&&hh)
setup dZ=eu
setup ka=eu||(q&&hk)
setup ea=ev
setup kc=ev||(q&&hl)
setup eb=et
setup kd=et||(q&&hj)
setup cY=aO
setup cZ=bT
setup db=aH
setup dc=bU
setup de=aG
setup df=bS
setup bv=ix53
setup gU=q&&ix55
setup ag=q
setup dg=cC
setup dh=cD
setup di=cE
setup kh=ix70 !="Off"
setup cc=ix68 !="Off"||ix69 !="Off"||ix70 !="Off"
setup ke=cC&&fZ
setup kf=cD&&ga
setup kg=cE&&gb
setup fM=rollS1Col1==color.transparent?rollCol1:rollS1Col1
setup ep=rollS2Col1==color.transparent?rollCol1:rollS2Col1
setup fN=rollS1Col2==color.transparent?rollCol2:rollS1Col2
setup eq=rollS2Col2==color.transparent?rollCol2:rollS2Col2
setup fO=rollS1Col3==color.transparent?rollCol3:rollS1Col3
setup er=rollS2Col3==color.transparent?rollCol3:rollS2Col3
setup ff=nvCol4H==color.transparent?color4H:nvCol4H
setup fg=nvColD==color.transparent?colorDaily:nvColD
setup fj=nvColW==color.transparent?colorWeekly:nvColW
setup fh=nvColM==color.transparent?colorMonthly:nvColM
setup fi=nvColQ==color.transparent?colorQuarterly:nvColQ
setup fk=nvColY==color.transparent?colorYearly:nvColY
setup hz=std1Color==color.transparent?color4H:std1Color
setup fp=ix5==color.transparent?color4H:ix5
setup hA=ix8==color.transparent?color4H:ix8
setup hC=std1Color==color.transparent?colorDaily:std1Color
setup fq=ix5==color.transparent?colorDaily:ix5
setup hD=ix8==color.transparent?colorDaily:ix8
setup hX=std1Color==color.transparent?colorWeekly:std1Color
setup fK=ix5==color.transparent?colorWeekly:ix5
setup hY=ix8==color.transparent?colorWeekly:ix8
setup hK=std1Color==color.transparent?colorMonthly:std1Color
setup fI=ix5==color.transparent?colorMonthly:ix5
setup hL=ix8==color.transparent?colorMonthly:ix8
setup hM=std1Color==color.transparent?colorQuarterly:std1Color
setup fJ=ix5==color.transparent?colorQuarterly:ix5
setup hO=ix8==color.transparent?colorQuarterly:ix8
setup hZ=std1Color==color.transparent?colorYearly:std1Color
setup fL=ix5==color.transparent?colorYearly:ix5
setup ia=ix8==color.transparent?colorYearly:ix8
setup jE=ix0=="HLC3 · 4H"||ix0=="OHLC4 · 4H"||ix0=="HL2 · 4H"||ix0=="Close · 4H"
setup aa=jE&&!time.isCalendar(context.timeframe)&&aM<=14400&&14400-(int(math.floor(14400.0/float(aM)))??0)*aM==0
setup jF=aa&&(gY||gW||gX||gZ)
data higher=subscribe(data.ohlcv,timeframe:4h,history:jF?2500:0)
setup cj=ix69 !="Off"
setup kY=ix69=="VPOC"||ix69=="Both"
setup kX=ix69=="TPOC"||ix69=="Both"
setup fu=ix70=="Volume"||ix70=="Both"
setup ft=ix70=="TPO"||ix70=="Both"
setup fs=ix68 !="Off"||cj||ix70 !="Off"
setup do=pfRankHud&&ix11&&fs
setup fr=ix70 !="Off"||do
setup hH=ix68=="VPOC"||ix68=="Both"
setup hG=ix68=="TPOC"||ix68=="Both"
setup kV=hH||kY||fu||do
setup kU=hG||kX||ft
setup hF=ix67=="4H"?14400:86400
setup kW=!time.isCalendar(context.timeframe)&&aM<=hF&&(int(math.floor(float(hF)/float(aM)))??0)*aM==hF
setup qY=ix67=="Quarterly"||ix67=="Yearly"
setup b8=tf(hlMP=="Month"?"1M":hlMP=="Quarter"?"3M":"1Y")
setup b7=tf(hlWP=="Week"?"1W":hlWP=="Quarter"?"3M":"1Y")
setup hlMC=hlMP=="Month"?"M":hlMP=="Quarter"?"Q":"Y"
setup hlWC=hlWP=="Week"?"W":hlWP=="Quarter"?"Q":"Y"
setup aZ=tf(ix67=="4H"?"4h":(ix67=="Daily"?"1D":(ix67=="Weekly"?"1W":(ix67=="Monthly"?"1M":(ix67=="Quarterly"?"3M":"1Y")))))
setup bp=tf(qY?"1D":pfBlock)
setup mW=time.tfSeconds(bp)
data pfData=subscribe(data.volume,timeframe:bp,history:fs&&!qY?250:0)
data pfDay=subscribe(data.ohlcv,timeframe:1D,history:fs&&qY?800:0)
plot(
p4h=plot.line(title:"4H VWAP",color:color4H,width:width4H)
p4h_s1u=plot.line(title:"4H +1σ",color:hz,width:1.0,style:a0,showValue:false,showLabel:false)
p4h_s1d=plot.line(title:"4H -1σ",color:hz,width:1.0,style:a0,showValue:false,showLabel:false)
p4h_s2u=plot.line(title:"4H +2σ",color:fp,width:1.0,style:a0,showValue:false,showLabel:false)
p4h_s2d=plot.line(title:"4H -2σ",color:fp,width:1.0,style:a0,showValue:false,showLabel:false)
p4h_s3u=plot.line(title:"4H +3σ",color:hA,width:1.0,style:a4,showValue:false,showLabel:false)
p4h_s3d=plot.line(title:"4H -3σ",color:hA,width:1.0,style:a4,showValue:false,showLabel:false)
pd=plot.line(title:"Daily VWAP",color:colorDaily,width:widthDaily)
pd_s1u=plot.line(title:"D +1σ",color:hC,width:1.0,style:a0,showValue:false,showLabel:false)
pd_s1d=plot.line(title:"D -1σ",color:hC,width:1.0,style:a0,showValue:false,showLabel:false)
pd_s2u=plot.line(title:"D +2σ",color:fq,width:1.0,style:a0,showValue:false,showLabel:false)
pd_s2d=plot.line(title:"D -2σ",color:fq,width:1.0,style:a0,showValue:false,showLabel:false)
pd_s3u=plot.line(title:"D +3σ",color:hD,width:1.0,style:a4,showValue:false,showLabel:false)
pd_s3d=plot.line(title:"D -3σ",color:hD,width:1.0,style:a4,showValue:false,showLabel:false)
pw=plot.line(title:aa?"Weekly VWAP · 4H":"Weekly VWAP",color:colorWeekly,width:widthWeekly)
pw_s1u=plot.line(title:"W +1σ",color:hX,width:1.0,style:a0,showValue:false,showLabel:false)
pw_s1d=plot.line(title:"W -1σ",color:hX,width:1.0,style:a0,showValue:false,showLabel:false)
pw_s2u=plot.line(title:"W +2σ",color:fK,width:1.0,style:a0,showValue:false,showLabel:false)
pw_s2d=plot.line(title:"W -2σ",color:fK,width:1.0,style:a0,showValue:false,showLabel:false)
pw_s3u=plot.line(title:"W +3σ",color:hY,width:1.0,style:a4,showValue:false,showLabel:false)
pw_s3d=plot.line(title:"W -3σ",color:hY,width:1.0,style:a4,showValue:false,showLabel:false)
pm=plot.line(title:aa?"Monthly VWAP · 4H":"Monthly VWAP",color:colorMonthly,width:widthMonthly)
pm_s1u=plot.line(title:"M +1σ",color:hK,width:1.0,style:a0,showValue:false,showLabel:false)
pm_s1d=plot.line(title:"M -1σ",color:hK,width:1.0,style:a0,showValue:false,showLabel:false)
pm_s2u=plot.line(title:"M +2σ",color:fI,width:1.0,style:a0,showValue:false,showLabel:false)
pm_s2d=plot.line(title:"M -2σ",color:fI,width:1.0,style:a0,showValue:false,showLabel:false)
pm_s3u=plot.line(title:"M +3σ",color:hL,width:1.0,style:a4,showValue:false,showLabel:false)
pm_s3d=plot.line(title:"M -3σ",color:hL,width:1.0,style:a4,showValue:false,showLabel:false)
pq=plot.line(title:aa?"Quarterly VWAP · 4H":"Quarterly VWAP",color:colorQuarterly,width:widthQuarterly)
pq_s1u=plot.line(title:"Q +1σ",color:hM,width:1.0,style:a0,showValue:false,showLabel:false)
pq_s1d=plot.line(title:"Q -1σ",color:hM,width:1.0,style:a0,showValue:false,showLabel:false)
pq_s2u=plot.line(title:"Q +2σ",color:fJ,width:1.0,style:a0,showValue:false,showLabel:false)
pq_s2d=plot.line(title:"Q -2σ",color:fJ,width:1.0,style:a0,showValue:false,showLabel:false)
pq_s3u=plot.line(title:"Q +3σ",color:hO,width:1.0,style:a4,showValue:false,showLabel:false)
pq_s3d=plot.line(title:"Q -3σ",color:hO,width:1.0,style:a4,showValue:false,showLabel:false)
py=plot.line(title:aa?"Yearly VWAP · 4H":"Yearly VWAP",color:colorYearly,width:widthYearly)
py_s1u=plot.line(title:"Y +1σ",color:hZ,width:1.0,style:a0,showValue:false,showLabel:false)
py_s1d=plot.line(title:"Y -1σ",color:hZ,width:1.0,style:a0,showValue:false,showLabel:false)
py_s2u=plot.line(title:"Y +2σ",color:fL,width:1.0,style:a0,showValue:false,showLabel:false)
py_s2d=plot.line(title:"Y -2σ",color:fL,width:1.0,style:a0,showValue:false,showLabel:false)
py_s3u=plot.line(title:"Y +3σ",color:ia,width:1.0,style:a4,showValue:false,showLabel:false)
py_s3d=plot.line(title:"Y -3σ",color:ia,width:1.0,style:a4,showValue:false,showLabel:false)
pSessAsia=plot.line(title:"Asia VWAP",color:ix22,width:ix30,showLabel:false)
pSessLondon=plot.line(title:"London VWAP",color:ix24,width:ix30,showLabel:false)
pSessNY=plot.line(title:"New York VWAP",color:ix26,width:ix30,showLabel:false)
pSessClose=plot.line(title:"NY Close VWAP",color:ix28,width:ix30,showLabel:false)
pMHigh=plot.line(title:str.format("{0} High AVWAP",hlMC),color:ix32,width:2.0,showLabel:!ak)
pMLow=plot.line(title:str.format("{0} Low AVWAP",hlMC),color:ix33,width:2.0,showLabel:!ak)
pPrevMHigh=plot.line(title:str.format("p{0} High AVWAP",hlMC),color:ix35,width:2.0,style:a0,showLabel:false)
pPrevMLow=plot.line(title:str.format("p{0} Low AVWAP",hlMC),color:ix36,width:2.0,style:a0,showLabel:false)
pWHigh=plot.line(title:str.format("{0} High AVWAP",hlWC),color:ix37,width:1.5,showLabel:!ak)
pWLow=plot.line(title:str.format("{0} Low AVWAP",hlWC),color:ix38,width:1.5,showLabel:!ak)
pPrevWHigh=plot.line(title:str.format("p{0} High AVWAP",hlWC),color:ix40,width:1.5,style:a0,showLabel:false)
pPrevWLow=plot.line(title:str.format("p{0} Low AVWAP",hlWC),color:ix41,width:1.5,style:a0,showLabel:false)
pDHigh=plot.line(title:"D High AVWAP",color:ix42,width:1.5,showLabel:!ak)
pDLow=plot.line(title:"D Low AVWAP",color:ix43,width:1.5,showLabel:!ak)
pPrevDHigh=plot.line(title:"pD High AVWAP",color:ix45,width:1.5,style:a0,showLabel:false)
pPrevDLow=plot.line(title:"pD Low AVWAP",color:ix46,width:1.5,style:a0,showLabel:false)
pCustom=plot.line(title:"Custom AVWAP",color:ix54,width:2.0)
pCust_s1u=plot.line(title:"Custom +1σ",color:color.withAlpha(ix54,150),width:1.0,style:a0,showValue:false,showLabel:false)
pCust_s1d=plot.line(title:"Custom -1σ",color:color.withAlpha(ix54,150),width:1.0,style:a0,showValue:false,showLabel:false)
pCust_s2u=plot.line(title:"Custom +2σ",color:color.withAlpha(ix54,110),width:1.0,style:a4,showValue:false,showLabel:false)
pCust_s2d=plot.line(title:"Custom -2σ",color:color.withAlpha(ix54,110),width:1.0,style:a4,showValue:false,showLabel:false)
pr1=plot.line(title:ns,color:rollCol1,width:ix21)
pr2=plot.line(title:nu,color:rollCol2,width:ix21)
pr3=plot.line(title:nw,color:rollCol3,width:ix21)
nvAx4H_1=plot.line(title:"NV 4H 1",color:ff,width:1.0,showLabel:false)
nvAx4H_2=plot.line(title:"NV 4H 2",color:ff,width:1.0,showLabel:false)
nvAx4H_3=plot.line(title:"NV 4H 3",color:ff,width:1.0,showLabel:false)
nvAxD_1=plot.line(title:"NV D 1",color:fg,width:1.0,showLabel:false)
nvAxD_2=plot.line(title:"NV D 2",color:fg,width:1.0,showLabel:false)
nvAxD_3=plot.line(title:"NV D 3",color:fg,width:1.0,showLabel:false)
nvAxW_1=plot.line(title:"NV W 1",color:fj,width:1.0,showLabel:false)
nvAxW_2=plot.line(title:"NV W 2",color:fj,width:1.0,showLabel:false)
nvAxW_3=plot.line(title:"NV W 3",color:fj,width:1.0,showLabel:false)
nvAxM_1=plot.line(title:"NV M 1",color:fh,width:1.0,showLabel:false)
nvAxM_2=plot.line(title:"NV M 2",color:fh,width:1.0,showLabel:false)
nvAxM_3=plot.line(title:"NV M 3",color:fh,width:1.0,showLabel:false)
nvAxQ_1=plot.line(title:"NV Q 1",color:fi,width:1.0,showLabel:false)
nvAxQ_2=plot.line(title:"NV Q 2",color:fi,width:1.0,showLabel:false)
nvAxQ_3=plot.line(title:"NV Q 3",color:fi,width:1.0,showLabel:false)
nvAxY_1=plot.line(title:"NV Y 1",color:fk,width:1.0,showLabel:false)
nvAxY_2=plot.line(title:"NV Y 2",color:fk,width:1.0,showLabel:false)
nvAxY_3=plot.line(title:"NV Y 3",color:fk,width:1.0,showLabel:false)
nvAxAS_1=plot.line(title:"NV AS 1",color:ix22,width:1.0,showLabel:false)
nvAxAS_2=plot.line(title:"NV AS 2",color:ix22,width:1.0,showLabel:false)
nvAxAS_3=plot.line(title:"NV AS 3",color:ix22,width:1.0,showLabel:false)
nvAxLN_1=plot.line(title:"NV LN 1",color:ix24,width:1.0,showLabel:false)
nvAxLN_2=plot.line(title:"NV LN 2",color:ix24,width:1.0,showLabel:false)
nvAxLN_3=plot.line(title:"NV LN 3",color:ix24,width:1.0,showLabel:false)
nvAxNY_1=plot.line(title:"NV NY 1",color:ix26,width:1.0,showLabel:false)
nvAxNY_2=plot.line(title:"NV NY 2",color:ix26,width:1.0,showLabel:false)
nvAxNY_3=plot.line(title:"NV NY 3",color:ix26,width:1.0,showLabel:false)
nvAxNC_1=plot.line(title:"NV NC 1",color:ix28,width:1.0,showLabel:false)
nvAxNC_2=plot.line(title:"NV NC 2",color:ix28,width:1.0,showLabel:false)
nvAxMH_1=plot.line(title:"NV MH 1",color:ix35,width:1.0,showLabel:false)
nvAxMH_2=plot.line(title:"NV MH 2",color:ix35,width:1.0,showLabel:false)
nvAxMH_3=plot.line(title:"NV MH 3",color:ix35,width:1.0,showLabel:false)
nvAxML_1=plot.line(title:"NV ML 1",color:ix36,width:1.0,showLabel:false)
nvAxML_2=plot.line(title:"NV ML 2",color:ix36,width:1.0,showLabel:false)
nvAxML_3=plot.line(title:"NV ML 3",color:ix36,width:1.0,showLabel:false)
nvAxWH_1=plot.line(title:"NV WH 1",color:ix40,width:1.0,showLabel:false)
nvAxWH_2=plot.line(title:"NV WH 2",color:ix40,width:1.0,showLabel:false)
nvAxWH_3=plot.line(title:"NV WH 3",color:ix40,width:1.0,showLabel:false)
nvAxWL_1=plot.line(title:"NV WL 1",color:ix41,width:1.0,showLabel:false)
nvAxWL_2=plot.line(title:"NV WL 2",color:ix41,width:1.0,showLabel:false)
nvAxWL_3=plot.line(title:"NV WL 3",color:ix41,width:1.0,showLabel:false)
nvAxDH_1=plot.line(title:"NV DH 1",color:ix45,width:1.0,showLabel:false)
nvAxDH_2=plot.line(title:"NV DH 2",color:ix45,width:1.0,showLabel:false)
nvAxDH_3=plot.line(title:"NV DH 3",color:ix45,width:1.0,showLabel:false)
nvAxDL_1=plot.line(title:"NV DL 1",color:ix46,width:1.0,showLabel:false)
nvAxDL_2=plot.line(title:"NV DL 2",color:ix46,width:1.0,showLabel:false)
nvAxDL_3=plot.line(title:"NV DL 3",color:ix46,width:1.0,showLabel:false)
nvAxNC_3=plot.line(title:"NV NC 3",color:ix28,width:1.0,showLabel:false)
pSessAsia_s1u=plot.line(title:"Asia +1σ",color:color.withAlpha(ix22,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessAsia_s1d=plot.line(title:"Asia -1σ",color:color.withAlpha(ix22,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessAsia_s2u=plot.line(title:"Asia +2σ",color:color.withAlpha(ix22,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessAsia_s2d=plot.line(title:"Asia -2σ",color:color.withAlpha(ix22,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessLondon_s1u=plot.line(title:"London +1σ",color:color.withAlpha(ix24,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessLondon_s1d=plot.line(title:"London -1σ",color:color.withAlpha(ix24,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessLondon_s2u=plot.line(title:"London +2σ",color:color.withAlpha(ix24,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessLondon_s2d=plot.line(title:"London -2σ",color:color.withAlpha(ix24,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessNY_s1u=plot.line(title:"NY +1σ",color:color.withAlpha(ix26,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessNY_s1d=plot.line(title:"NY -1σ",color:color.withAlpha(ix26,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessNY_s2u=plot.line(title:"NY +2σ",color:color.withAlpha(ix26,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessNY_s2d=plot.line(title:"NY -2σ",color:color.withAlpha(ix26,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessClose_s1u=plot.line(title:"NY Close +1σ",color:color.withAlpha(ix28,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessClose_s1d=plot.line(title:"NY Close -1σ",color:color.withAlpha(ix28,150),width:1.0,style:a0,showValue:false,showLabel:false)
pSessClose_s2u=plot.line(title:"NY Close +2σ",color:color.withAlpha(ix28,110),width:1.0,style:a4,showValue:false,showLabel:false)
pSessClose_s2d=plot.line(title:"NY Close -2σ",color:color.withAlpha(ix28,110),width:1.0,style:a4,showValue:false,showLabel:false)
pMHigh_s1u=plot.line(title:"M High +1σ",color:color.withAlpha(ix32,150),width:1.0,style:a0,showValue:false,showLabel:false)
pMHigh_s1d=plot.line(title:"M High -1σ",color:color.withAlpha(ix32,150),width:1.0,style:a0,showValue:false,showLabel:false)
pMHigh_s2u=plot.line(title:"M High +2σ",color:color.withAlpha(ix32,110),width:1.0,style:a4,showValue:false,showLabel:false)
pMHigh_s2d=plot.line(title:"M High -2σ",color:color.withAlpha(ix32,110),width:1.0,style:a4,showValue:false,showLabel:false)
pMLow_s1u=plot.line(title:"M Low +1σ",color:color.withAlpha(ix33,150),width:1.0,style:a0,showValue:false,showLabel:false)
pMLow_s1d=plot.line(title:"M Low -1σ",color:color.withAlpha(ix33,150),width:1.0,style:a0,showValue:false,showLabel:false)
pMLow_s2u=plot.line(title:"M Low +2σ",color:color.withAlpha(ix33,110),width:1.0,style:a4,showValue:false,showLabel:false)
pMLow_s2d=plot.line(title:"M Low -2σ",color:color.withAlpha(ix33,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevMHigh_s1u=plot.line(title:"M-1 High +1σ",color:color.withAlpha(ix35,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevMHigh_s1d=plot.line(title:"M-1 High -1σ",color:color.withAlpha(ix35,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevMHigh_s2u=plot.line(title:"M-1 High +2σ",color:color.withAlpha(ix35,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevMHigh_s2d=plot.line(title:"M-1 High -2σ",color:color.withAlpha(ix35,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevMLow_s1u=plot.line(title:"M-1 Low +1σ",color:color.withAlpha(ix36,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevMLow_s1d=plot.line(title:"M-1 Low -1σ",color:color.withAlpha(ix36,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevMLow_s2u=plot.line(title:"M-1 Low +2σ",color:color.withAlpha(ix36,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevMLow_s2d=plot.line(title:"M-1 Low -2σ",color:color.withAlpha(ix36,110),width:1.0,style:a4,showValue:false,showLabel:false)
pWHigh_s1u=plot.line(title:"W High +1σ",color:color.withAlpha(ix37,150),width:1.0,style:a0,showValue:false,showLabel:false)
pWHigh_s1d=plot.line(title:"W High -1σ",color:color.withAlpha(ix37,150),width:1.0,style:a0,showValue:false,showLabel:false)
pWHigh_s2u=plot.line(title:"W High +2σ",color:color.withAlpha(ix37,110),width:1.0,style:a4,showValue:false,showLabel:false)
pWHigh_s2d=plot.line(title:"W High -2σ",color:color.withAlpha(ix37,110),width:1.0,style:a4,showValue:false,showLabel:false)
pWLow_s1u=plot.line(title:"W Low +1σ",color:color.withAlpha(ix38,150),width:1.0,style:a0,showValue:false,showLabel:false)
pWLow_s1d=plot.line(title:"W Low -1σ",color:color.withAlpha(ix38,150),width:1.0,style:a0,showValue:false,showLabel:false)
pWLow_s2u=plot.line(title:"W Low +2σ",color:color.withAlpha(ix38,110),width:1.0,style:a4,showValue:false,showLabel:false)
pWLow_s2d=plot.line(title:"W Low -2σ",color:color.withAlpha(ix38,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevWHigh_s1u=plot.line(title:"W-1 High +1σ",color:color.withAlpha(ix40,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevWHigh_s1d=plot.line(title:"W-1 High -1σ",color:color.withAlpha(ix40,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevWHigh_s2u=plot.line(title:"W-1 High +2σ",color:color.withAlpha(ix40,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevWHigh_s2d=plot.line(title:"W-1 High -2σ",color:color.withAlpha(ix40,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevWLow_s1u=plot.line(title:"W-1 Low +1σ",color:color.withAlpha(ix41,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevWLow_s1d=plot.line(title:"W-1 Low -1σ",color:color.withAlpha(ix41,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevWLow_s2u=plot.line(title:"W-1 Low +2σ",color:color.withAlpha(ix41,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevWLow_s2d=plot.line(title:"W-1 Low -2σ",color:color.withAlpha(ix41,110),width:1.0,style:a4,showValue:false,showLabel:false)
pDHigh_s1u=plot.line(title:"D High +1σ",color:color.withAlpha(ix42,150),width:1.0,style:a0,showValue:false,showLabel:false)
pDHigh_s1d=plot.line(title:"D High -1σ",color:color.withAlpha(ix42,150),width:1.0,style:a0,showValue:false,showLabel:false)
pDHigh_s2u=plot.line(title:"D High +2σ",color:color.withAlpha(ix42,110),width:1.0,style:a4,showValue:false,showLabel:false)
pDHigh_s2d=plot.line(title:"D High -2σ",color:color.withAlpha(ix42,110),width:1.0,style:a4,showValue:false,showLabel:false)
pDLow_s1u=plot.line(title:"D Low +1σ",color:color.withAlpha(ix43,150),width:1.0,style:a0,showValue:false,showLabel:false)
pDLow_s1d=plot.line(title:"D Low -1σ",color:color.withAlpha(ix43,150),width:1.0,style:a0,showValue:false,showLabel:false)
pDLow_s2u=plot.line(title:"D Low +2σ",color:color.withAlpha(ix43,110),width:1.0,style:a4,showValue:false,showLabel:false)
pDLow_s2d=plot.line(title:"D Low -2σ",color:color.withAlpha(ix43,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevDHigh_s1u=plot.line(title:"D-1 High +1σ",color:color.withAlpha(ix45,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevDHigh_s1d=plot.line(title:"D-1 High -1σ",color:color.withAlpha(ix45,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevDHigh_s2u=plot.line(title:"D-1 High +2σ",color:color.withAlpha(ix45,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevDHigh_s2d=plot.line(title:"D-1 High -2σ",color:color.withAlpha(ix45,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevDLow_s1u=plot.line(title:"D-1 Low +1σ",color:color.withAlpha(ix46,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevDLow_s1d=plot.line(title:"D-1 Low -1σ",color:color.withAlpha(ix46,150),width:1.0,style:a0,showValue:false,showLabel:false)
pPrevDLow_s2u=plot.line(title:"D-1 Low +2σ",color:color.withAlpha(ix46,110),width:1.0,style:a4,showValue:false,showLabel:false)
pPrevDLow_s2d=plot.line(title:"D-1 Low -2σ",color:color.withAlpha(ix46,110),width:1.0,style:a4,showValue:false,showLabel:false)
pr1_s1u=plot.line(title:"R1 +1σ",color:fM,width:1.0,style:a0,showValue:false,showLabel:false)
pr1_s1d=plot.line(title:"R1 -1σ",color:fM,width:1.0,style:a0,showValue:false,showLabel:false)
pr1_s2u=plot.line(title:"R1 +2σ",color:ep,width:1.0,style:a0,showValue:false,showLabel:false)
pr1_s2d=plot.line(title:"R1 -2σ",color:ep,width:1.0,style:a0,showValue:false,showLabel:false)
pr2_s1u=plot.line(title:"R2 +1σ",color:fN,width:1.0,style:a0,showValue:false,showLabel:false)
pr2_s1d=plot.line(title:"R2 -1σ",color:fN,width:1.0,style:a0,showValue:false,showLabel:false)
pr2_s2u=plot.line(title:"R2 +2σ",color:eq,width:1.0,style:a0,showValue:false,showLabel:false)
pr2_s2d=plot.line(title:"R2 -2σ",color:eq,width:1.0,style:a0,showValue:false,showLabel:false)
pr3_s1u=plot.line(title:"R3 +1σ",color:fO,width:1.0,style:a0,showValue:false,showLabel:false)
pr3_s1d=plot.line(title:"R3 -1σ",color:fO,width:1.0,style:a0,showValue:false,showLabel:false)
pr3_s2u=plot.line(title:"R3 +2σ",color:er,width:1.0,style:a0,showValue:false,showLabel:false)
pr3_s2d=plot.line(title:"R3 -2σ",color:er,width:1.0,style:a0,showValue:false,showLabel:false)
)
fill(
f4h_s1=fill.between(p4h_s1u,p4h_s1d,color:color.withAlpha(hz,E))
f4h_s2u=fill.between(p4h_s2u,p4h_s1u,color:color.withAlpha(fp,E))
f4h_s2d=fill.between(p4h_s1d,p4h_s2d,color:color.withAlpha(fp,E))
f4h_s3=fill.between(p4h_s3u,p4h_s3d,color:color.withAlpha(hA,E))
fd_s1=fill.between(pd_s1u,pd_s1d,color:color.withAlpha(hC,E))
fd_s2u=fill.between(pd_s2u,pd_s1u,color:color.withAlpha(fq,E))
fd_s2d=fill.between(pd_s1d,pd_s2d,color:color.withAlpha(fq,E))
fd_s3=fill.between(pd_s3u,pd_s3d,color:color.withAlpha(hD,E))
fw_s1=fill.between(pw_s1u,pw_s1d,color:color.withAlpha(hX,E))
fw_s2u=fill.between(pw_s2u,pw_s1u,color:color.withAlpha(fK,E))
fw_s2d=fill.between(pw_s1d,pw_s2d,color:color.withAlpha(fK,E))
fw_s3=fill.between(pw_s3u,pw_s3d,color:color.withAlpha(hY,E))
fm_s1=fill.between(pm_s1u,pm_s1d,color:color.withAlpha(hK,E))
fm_s2u=fill.between(pm_s2u,pm_s1u,color:color.withAlpha(fI,E))
fm_s2d=fill.between(pm_s1d,pm_s2d,color:color.withAlpha(fI,E))
fm_s3=fill.between(pm_s3u,pm_s3d,color:color.withAlpha(hL,E))
fq_s1=fill.between(pq_s1u,pq_s1d,color:color.withAlpha(hM,E))
fq_s2u=fill.between(pq_s2u,pq_s1u,color:color.withAlpha(fJ,E))
fq_s2d=fill.between(pq_s1d,pq_s2d,color:color.withAlpha(fJ,E))
fq_s3=fill.between(pq_s3u,pq_s3d,color:color.withAlpha(hO,E))
fy_s1=fill.between(py_s1u,py_s1d,color:color.withAlpha(hZ,E))
fy_s2u=fill.between(py_s2u,py_s1u,color:color.withAlpha(fL,E))
fy_s2d=fill.between(py_s1d,py_s2d,color:color.withAlpha(fL,E))
fy_s3=fill.between(py_s3u,py_s3d,color:color.withAlpha(ia,E))
pSessAsia_f1=fill.between(pSessAsia_s1u,pSessAsia_s1d,color:color.withAlpha(ix22,E))
pSessAsia_f2u=fill.between(pSessAsia_s2u,pSessAsia_s1u,color:color.withAlpha(ix22,aD))
pSessAsia_f2d=fill.between(pSessAsia_s1d,pSessAsia_s2d,color:color.withAlpha(ix22,aD))
pSessLondon_f1=fill.between(pSessLondon_s1u,pSessLondon_s1d,color:color.withAlpha(ix24,E))
pSessLondon_f2u=fill.between(pSessLondon_s2u,pSessLondon_s1u,color:color.withAlpha(ix24,aD))
pSessLondon_f2d=fill.between(pSessLondon_s1d,pSessLondon_s2d,color:color.withAlpha(ix24,aD))
pSessNY_f1=fill.between(pSessNY_s1u,pSessNY_s1d,color:color.withAlpha(ix26,E))
pSessNY_f2u=fill.between(pSessNY_s2u,pSessNY_s1u,color:color.withAlpha(ix26,aD))
pSessNY_f2d=fill.between(pSessNY_s1d,pSessNY_s2d,color:color.withAlpha(ix26,aD))
pSessClose_f1=fill.between(pSessClose_s1u,pSessClose_s1d,color:color.withAlpha(ix28,E))
pSessClose_f2u=fill.between(pSessClose_s2u,pSessClose_s1u,color:color.withAlpha(ix28,aD))
pSessClose_f2d=fill.between(pSessClose_s1d,pSessClose_s2d,color:color.withAlpha(ix28,aD))
pCust_f1=fill.between(pCust_s1u,pCust_s1d,color:color.withAlpha(ix54,E))
pCust_f2u=fill.between(pCust_s2u,pCust_s1u,color:color.withAlpha(ix54,aD))
pCust_f2d=fill.between(pCust_s1d,pCust_s2d,color:color.withAlpha(ix54,aD))
pr1_f1=fill.between(pr1_s1u,pr1_s1d,color:color.withAlpha(fM,E))
pr1_f2u=fill.between(pr1_s2u,pr1_s1u,color:color.withAlpha(ep,E))
pr1_f2d=fill.between(pr1_s1d,pr1_s2d,color:color.withAlpha(ep,E))
pr2_f1=fill.between(pr2_s1u,pr2_s1d,color:color.withAlpha(fN,E))
pr2_f2u=fill.between(pr2_s2u,pr2_s1u,color:color.withAlpha(eq,E))
pr2_f2d=fill.between(pr2_s1d,pr2_s2d,color:color.withAlpha(eq,E))
pr3_f1=fill.between(pr3_s1u,pr3_s1d,color:color.withAlpha(fO,E))
pr3_f2u=fill.between(pr3_s2u,pr3_s1u,color:color.withAlpha(er,E))
pr3_f2d=fill.between(pr3_s1d,pr3_s2d,color:color.withAlpha(er,E))
pMHigh_f1=fill.between(pMHigh_s1u,pMHigh_s1d,color:color.withAlpha(ix32,E))
pMLow_f1=fill.between(pMLow_s1u,pMLow_s1d,color:color.withAlpha(ix33,E))
pPrevMHigh_f1=fill.between(pPrevMHigh_s1u,pPrevMHigh_s1d,color:color.withAlpha(ix35,E))
pPrevMLow_f1=fill.between(pPrevMLow_s1u,pPrevMLow_s1d,color:color.withAlpha(ix36,E))
pWHigh_f1=fill.between(pWHigh_s1u,pWHigh_s1d,color:color.withAlpha(ix37,E))
pWLow_f1=fill.between(pWLow_s1u,pWLow_s1d,color:color.withAlpha(ix38,E))
pPrevWHigh_f1=fill.between(pPrevWHigh_s1u,pPrevWHigh_s1d,color:color.withAlpha(ix40,E))
pPrevWLow_f1=fill.between(pPrevWLow_s1u,pPrevWLow_s1d,color:color.withAlpha(ix41,E))
pDHigh_f1=fill.between(pDHigh_s1u,pDHigh_s1d,color:color.withAlpha(ix42,E))
pDLow_f1=fill.between(pDLow_s1u,pDLow_s1d,color:color.withAlpha(ix43,E))
pPrevDHigh_f1=fill.between(pPrevDHigh_s1u,pPrevDHigh_s1d,color:color.withAlpha(ix45,E))
pPrevDLow_f1=fill.between(pPrevDLow_s1u,pPrevDLow_s1d,color:color.withAlpha(ix46,E))
)
type Qd{
period:string
price:float
vwap:float
message:string
}
type Qn{
period:string
level:float
score:int
message:string
}
alert(
vwapCrossUp=alert(title:"VWAP bullish cross",onClose:true,payload:Qd)
vwapCrossDown=alert(title:"VWAP bearish cross",onClose:true,payload:Qd)
bandUpper=alert(title:"Extension above σ band",onClose:true,payload:Qd)
bandLower=alert(title:"Extension below σ band",onClose:true,payload:Qd)
nakedTouched=alert(title:"Naked VWAP touched",onClose:true,payload:Qn)
)
type Qb{
id:int
code:string
level:float
startTime:time
touched:bool
score:int
vS:int
dS:int
dev:float
b1u:bool
b1d:bool
b2u:bool
b2d:bool
}
type Qk{
r:int
v:int
d:int
}
type Qf{
hi:float
lo:float
hiPV:float
hiV:float
hiP2:float
loPV:float
loV:float
loP2:float
pHiPV:float
pHiV:float
pHiP2:float
pLoPV:float
pLoV:float
pLoP2:float
hiD:float
loD:float
pHiD:float
pLoD:float
full:bool
hasPH:bool
hasPL:bool
usedPH:bool
usedPL:bool
newHi:bool
newLo:bool
newPH:bool
newPL:bool
pNewHi:bool
pNewLo:bool
pNewPH:bool
pNewPL:bool
fn step(mm:bool,eF:bool,eh:float,el:float,h:float,l:float,pv:float,p2:float,vol:float,aT:float,gD:bool){
self.pNewHi=self.newHi
self.pNewLo=self.newLo
self.pNewPH=self.newPH
self.pNewPL=self.newPL
if mm{
let ic=self.full&&self.hiV>0.0&&self.loV>0.0
self.full=eF
if ic{
self.newPH=self.hasPH
self.newPL=self.hasPL
self.pHiPV=self.hiPV
self.pHiV=self.hiV
self.pHiP2=self.hiP2
self.pHiD=self.hiD
self.hasPH=true
self.usedPH=false
self.pLoPV=self.loPV
self.pLoV=self.loV
self.pLoP2=self.loP2
self.pLoD=self.loD
self.hasPL=true
self.usedPL=false
}else{
self.newPH=false
self.newPL=false
}
self.hi=eh
self.lo=el
self.hiPV=pv
self.hiV=vol
self.hiP2=p2
self.loPV=pv
self.loV=vol
self.loP2=p2
self.hiD=aT
self.loD=aT
self.newHi=true
self.newLo=true
}else{
let nh=eh>self.hi
let nl=el<self.lo
if nh{
self.hi=eh
self.hiPV=pv
self.hiV=vol
self.hiP2=p2
self.hiD=aT
}else{
self.hiPV+=pv
self.hiV+=vol
self.hiP2+=p2
self.hiD+=aT
}
if nl{
self.lo=el
self.loPV=pv
self.loV=vol
self.loP2=p2
self.loD=aT
}else{
self.loPV+=pv
self.loV+=vol
self.loP2+=p2
self.loD+=aT
}
self.newHi=nh
self.newLo=nl
self.newPH=false
self.newPL=false
}
self.pHiPV+=pv
self.pHiV+=vol
self.pHiP2+=p2
self.pLoPV+=pv
self.pLoV+=vol
self.pLoP2+=p2
self.pHiD+=aT
self.pLoD+=aT
if self.hasPH&&self.pHiV>0.0{
let v=self.pHiPV/self.pHiV
if l<=v&&h>=v{
self.usedPH=true
}
}
if self.hasPL&&self.pLoV>0.0{
let v=self.pLoPV/self.pLoV
if l<=v&&h>=v{
self.usedPL=true
}
}
}
}
type Qg{
pv:float
v:float
p2:float
endTime:time
}
type Qe{
buckets:rolling<Qg>
sumPV:float
sumV:float
sumP2:float
curPV:float
curV:float
curP2:float
bucketStart:time?
lastTime:time?
fn step(ts:time,tf:timeframe,mi:int,pv:float,p2:float,vol:float){
let gt=ts-time.seconds(mi)
let first=self.buckets.first()
if first !=null&&first.endTime<=gt{
let lo=0
let hi=self.buckets.len
for k in 0..13{
if lo<hi{
let au=int(math.floor(float(lo+hi)/2.0))??lo
let G=self.buckets[au]
if G !=null&&G.endTime<=gt{
lo=au+1
}else{
hi=au
}
}
}
for k in 0..lo{
let G=self.buckets.shift()
if G !=null{
self.sumPV-=G.pv
self.sumV-=G.v
self.sumP2-=G.p2
}
}
if self.buckets.len==0{
self.sumPV=0.0
self.sumV=0.0
self.sumP2=0.0
}
}
let lL=time.floor(ts,tf)
if self.bucketStart==null||self.bucketStart !=lL{
let last=self.lastTime
if self.curV>0.0&&last !=null&&last>gt{
if self.buckets.isFull{
let ab=self.buckets.shift()
if ab !=null{
self.sumPV-=ab.pv
self.sumV-=ab.v
self.sumP2-=ab.p2
}
}
self.buckets.push(Qg{pv:self.curPV,v:self.curV,p2:self.curP2,endTime:last})
self.sumPV+=self.curPV
self.sumV+=self.curV
self.sumP2+=self.curP2
}
self.curPV=0.0
self.curV=0.0
self.curP2=0.0
self.bucketStart=lL
}
self.curPV+=pv
self.curV+=vol
self.curP2+=p2
self.lastTime=ts
}
fn value()->float?{
return bD(self.sumPV+self.curPV,self.sumV+self.curV,true)
}
fn dev()->float?{
return U(self.sumPV+self.curPV,self.sumV+self.curV,self.sumP2+self.curP2,true)
}
}
type Qi{
pv:float
v:float
p2:float
last:float?
lastD:float?
fn step(bm:bool,mo:bool,cH:bool,ks:bool,pv:float,p2:float,vol:float){
if mo{
if cH&&self.v>0.0{
self.last=self.pv/self.v
self.lastD=ks?U(self.pv,self.v,self.p2,true):null
}
self.pv=pv
self.v=vol
self.p2=p2
}else if bm{
self.pv+=pv
self.v+=vol
self.p2+=p2
}else if cH&&self.v>0.0{
self.last=self.pv/self.v
self.lastD=ks?U(self.pv,self.v,self.p2,true):null
}
}
fn value(bm:bool)->float?{
return bm&&self.v>0.0?self.pv/self.v:self.last
}
fn dev(bm:bool)->float?{
return bm&&self.v>0.0?U(self.pv,self.v,self.p2,true):self.lastD
}
}
state(
dk=entities.linePool(max:q?nvMax*(dl?2:1):1)
hp=entities.labelPool(max:q&&ho?nvMax:1,anchor:anchor.right)
hs=entities.labelPool(max:q&&hr?nvMax:1)
mQ=entities.linePool(max:q&&ix55?nvHistMax:1)
mR=entities.labelPool(max:q&&ix55&&ix56?nvHistMax:1)
levels=Qb[](q?nvMax:1)
nextNvId:int=1
bw=entities.labelPool(max:70,anchor:anchor.right)
bu=entities.linePool(max:ap?2000:1)
dV=entities.lineFillPool(max:mx?1000:1)
aA=int[](17)
aW=time[](lvSlots)
aX=float[](lvSlots)
aV=float[](lvSlots)
fd=int[](6)
dX=int[](6)
gP=int[](6)
gS=time[](6)
gT=float[](6)
gR=float[](6)
aB=entities.linePool(max:fe>0||dP||dR||dO?2000:1)
gC=int[](12)
dI=float[](24)
bX=int[](12)
bY=time[](2)
topIds=int[](48)
fo=entities.linePool(max:q&&nvStd1On?nvMax*(kF?4:2):1)
hudN:int=1
topReady:bool=false
topChanged:bool=false
bN=int[](48)
jG=entities.labelPool(max:ix11?16:1,anchor:jH?(gB?anchor.topRight:anchor.topLeft):(gB?anchor.bottomRight:anchor.bottomLeft))
momentOrigin:float?=null
firstLoaded:time?=null
customPartial:bool=false
prevBandUpper:bool=false
prevBandLower:bool=false
last4H_V:float?=null
lastD_V:float?=null
lastW_V:float?=null
lastM_V:float?=null
lastQ_V:float?=null
lastY_V:float?=null
last4H_D:float?=null
lastD_D:float?=null
lastW_D:float?=null
lastM_D:float?=null
lastQ_D:float?=null
lastY_D:float?=null
prevRefV:float?=null
vol4H:float=0.0
volD:float=0.0
volW:float=0.0
volM:float=0.0
volQ:float=0.0
volY:float=0.0
jd=rolling<float>(co?nvScoreN:1)
jg=rolling<float>(co?nvScoreN:1)
dlt4H:float=0.0
seen4H:bool=false
jf=rolling<float>(cu?nvScoreN:1)
ji=rolling<float>(cu?nvScoreN:1)
dltD:float=0.0
seenD:bool=false
jA=rolling<float>(cA?nvScoreN:1)
jr=rolling<float>(cA?nvScoreN:1)
dltW:float=0.0
seenW:bool=false
jv=rolling<float>(cx?nvScoreN:1)
jl=rolling<float>(cx?nvScoreN:1)
dltM:float=0.0
seenM:bool=false
jz=rolling<float>(cz?nvScoreN:1)
jq=rolling<float>(cz?nvScoreN:1)
dltQ:float=0.0
seenQ:bool=false
jB=rolling<float>(cB?nvScoreN:1)
js=rolling<float>(cB?nvScoreN:1)
dltY:float=0.0
seenY:bool=false
eS=rolling<float>(cq?nvScoreN:1)
eW=rolling<float>(cq?nvScoreN:1)
eT=rolling<float>(cr?nvScoreN:1)
eX=rolling<float>(cr?nvScoreN:1)
eR=rolling<float>(cp?nvScoreN:1)
eV=rolling<float>(cp?nvScoreN:1)
je=rolling<float>(cs?nvScoreN:1)
jh=rolling<float>(cs?nvScoreN:1)
dltAS:float=0.0
seenAS:bool=false
ju=rolling<float>(cw?nvScoreN:1)
jj=rolling<float>(cw?nvScoreN:1)
dltLN:float=0.0
seenLN:bool=false
jy=rolling<float>(cy?nvScoreN:1)
jo=rolling<float>(cy?nvScoreN:1)
dltNY:float=0.0
seenNY:bool=false
jx=rolling<float>(ct?nvScoreN:1)
jm=rolling<float>(ct?nvScoreN:1)
dltNC:float=0.0
seenNC:bool=false
sAsia:Qi=Qi{pv:0.0,v:0.0,p2:0.0,last:null,lastD:null}
sLondon:Qi=Qi{pv:0.0,v:0.0,p2:0.0,last:null,lastD:null}
sNY:Qi=Qi{pv:0.0,v:0.0,p2:0.0,last:null,lastD:null}
sClose:Qi=Qi{pv:0.0,v:0.0,p2:0.0,last:null,lastD:null}
dL=time[](dP?256:1)
gI=float[](dP?256:1)
legMHn:int=0
legMHlt:time?=null
legMHlv:float=0.0
dN=time[](dP?256:1)
gJ=float[](dP?256:1)
legMLn:int=0
legMLlt:time?=null
legMLlv:float=0.0
legMIdx:int=0
legMJoin:bool=false
dT=time[](dR?256:1)
gK=float[](dR?256:1)
legWHn:int=0
legWHlt:time?=null
legWHlv:float=0.0
dU=time[](dR?256:1)
gL=float[](dR?256:1)
legWLn:int=0
legWLlt:time?=null
legWLlv:float=0.0
legWIdx:int=0
legWJoin:bool=false
dJ=time[](dO?256:1)
gG=float[](dO?256:1)
legDHn:int=0
legDHlt:time?=null
legDHlv:float=0.0
dK=time[](dO?256:1)
gH=float[](dO?256:1)
legDLn:int=0
legDLlt:time?=null
legDLlv:float=0.0
legDIdx:int=0
legDJoin:bool=false
ptM:Qf=Qf{hi:-1.0,lo:1e18,hiPV:0.0,hiV:0.0,hiP2:0.0,loPV:0.0,loV:0.0,loP2:0.0,pHiPV:0.0,pHiV:0.0,pHiP2:0.0,pLoPV:0.0,pLoV:0.0,pLoP2:0.0,hiD:0.0,loD:0.0,pHiD:0.0,pLoD:0.0,full:false,hasPH:false,hasPL:false,usedPH:false,usedPL:false,newHi:false,newLo:false,newPH:false,newPL:false,pNewHi:false,pNewLo:false,pNewPH:false,pNewPL:false}
ptW:Qf=Qf{hi:-1.0,lo:1e18,hiPV:0.0,hiV:0.0,hiP2:0.0,loPV:0.0,loV:0.0,loP2:0.0,pHiPV:0.0,pHiV:0.0,pHiP2:0.0,pLoPV:0.0,pLoV:0.0,pLoP2:0.0,hiD:0.0,loD:0.0,pHiD:0.0,pLoD:0.0,full:false,hasPH:false,hasPL:false,usedPH:false,usedPL:false,newHi:false,newLo:false,newPH:false,newPL:false,pNewHi:false,pNewLo:false,pNewPH:false,pNewPL:false}
ptD:Qf=Qf{hi:-1.0,lo:1e18,hiPV:0.0,hiV:0.0,hiP2:0.0,loPV:0.0,loV:0.0,loP2:0.0,pHiPV:0.0,pHiV:0.0,pHiP2:0.0,pLoPV:0.0,pLoV:0.0,pLoP2:0.0,hiD:0.0,loD:0.0,pHiD:0.0,pLoD:0.0,full:false,hasPH:false,hasPL:false,usedPH:false,usedPL:false,newHi:false,newLo:false,newPH:false,newPL:false,pNewHi:false,pNewLo:false,pNewPH:false,pNewPL:false}
custAnchored:bool=false
aF=entities.linePool(max:(lf?300:1)+(eY||ak?32:0))
aQ=entities.lineFillPool(max:le?300:1)
dr=entities.linePool(max:lf&&ix17?2000:1)
dq=entities.lineFillPool(max:le&&ix17?2000:1)
nextProjId:int=1
fB=rolling<float>(10)
fv=rolling<float>(10)
pjT4H:time?=null
fC=rolling<float>(10)
fw=rolling<float>(10)
pjTD:time?=null
fF=rolling<float>(10)
fz=rolling<float>(10)
pjTW:time?=null
fD=rolling<float>(10)
fx=rolling<float>(10)
pjTM:time?=null
fE=rolling<float>(10)
fy=rolling<float>(10)
pjTQ:time?=null
fG=rolling<float>(10)
fA=rolling<float>(10)
pjTY:time?=null
r1:Qe=Qe{buckets:rolling<Qg>(cC?rollCap1:1),sumPV:0.0,sumV:0.0,sumP2:0.0,curPV:0.0,curV:0.0,curP2:0.0,bucketStart:null,lastTime:null}
r2:Qe=Qe{buckets:rolling<Qg>(cD?rollCap2:1),sumPV:0.0,sumV:0.0,sumP2:0.0,curPV:0.0,curV:0.0,curP2:0.0,bucketStart:null,lastTime:null}
r3:Qe=Qe{buckets:rolling<Qg>(cE?rollCap3:1),sumPV:0.0,sumV:0.0,sumP2:0.0,curPV:0.0,curV:0.0,curP2:0.0,bucketStart:null,lastTime:null}
)
fn O(ts:time,nE:float)->time{
let seconds=(int(math.round(nE*60.0))??0)*60
return time.floor(ts-time.seconds(seconds),1D)+time.seconds(seconds)
}
fn U(pv:float,v:float,p2:float,ok:bool)->float?{
if !ok||v<=0.0{
return null
}
let m=pv/v-(momentOrigin??0.0)
return math.sqrt(math.max(0.0,p2/v-m*m))
}
fn al(p:PlotLine,B:color,me:bool,aU:bool,ae:bool,af:bool,oldV:float?,kv:float?){
let b9:float?=null
if !me{
p.plot(b9,color:invisible)
}else if ae{
p.plot(oldV??kv,color:invisible)
}else{
p.plot(kv,color:aU||af?invisible:B)
}
}
fn aC(iP:color,source:color)->color{
return iP==color.transparent?source:iP
}
fn lU(a:float)->int{
return int(math.round(a))??0
}
fn bD(pv:float,v:float,ok:bool)->float?{
return ok&&v>0.0?pv/v:null
}
fn kT(x:float,gA:rolling<float>,iu:bool)->int{
let n=math.min(nvScoreN,gA.len)
if n<3{
return 50
}
let xv=iu?math.abs(x):x
let cJ=0.0
for k in 0..n{
let hv=gA[gA.len-1-k]??0.0
let a=iu?math.abs(hv):hv
if a<xv{
cJ+=1.0
}
if a==xv{
cJ+=0.5
}
}
return int(math.round(100.0*cJ/float(n)))??50
}
fn ay(vol:float,aT:float,hv:rolling<float>,hd:rolling<float>)->Qk{
let v=kT(vol,hv,false)
let dm=kT(aT,hd,true)
let wv=math.max(0.0,nvWVol)
let wd=math.max(0.0,nvWDelta)
let r=int(math.round((wv*float(v)+wd*float(dm))/math.max(0.000001,wv+wd)))??50
return Qk{r:r,v:v,d:aT>=0.0?dm:-dm}
}
fn dC(x:float)->string{
if x>=100.0{
return str.format("{0:.2}",x)
}
if x>=1.0{
return str.format("{0:.4}",x)
}
return str.format("{0:.6}",x)
}
fn ig(e:Qb)->string{
let ds=e.dS>=0?str.format("+{0}",e.dS):str.format("{0}",e.dS)
if ix66=="R"{
return str.format("R{0}",e.score)
}
if ix66=="R + V"{
return str.format("R{0} · V{1}",e.score,e.vS)
}
return str.format("R{0} · V{1} · Δ{2}",e.score,e.vS,ds)
}
fn nB(e:Qb)->color{
if !nvScoreByDelta{
return bn(e.code)
}
return e.dS>=0?color.rgb(102,187,106):color.rgb(239,83,80)
}
fn jI(id:int)->bool{
for k in 0..topIds.len{
if topIds[k]==id{
return true
}
}
return false
}
fn mV(code:string)->color{
return match code{
"4H"=>color4H
"D"=>colorDaily
"W"=>colorWeekly
"M"=>colorMonthly
"Q"=>colorQuarterly
_=>colorYearly
}
}
fn bn(code:string)->color{
return match code{
"V"=>pfVColor
"T"=>ix72
"4H"=>ff
"D"=>fg
"W"=>fj
"M"=>fh
"Q"=>fi
"Y"=>fk
"AS"=>ix22
"LN"=>ix24
"NY"=>ix26
"NC"=>ix28
"MH"=>ix35
"ML"=>ix36
"WH"=>ix40
"WL"=>ix41
"DH"=>ix45
_=>ix46
}
}
fn aL(e:Qb,j:int)->float{
return match j{
0=>e.level+ix3*e.dev
1=>e.level-ix3*e.dev
2=>e.level+ix4*e.dev
_=>e.level-ix4*e.dev
}
}
fn dv(e:Qb,j:int)->bool{
let mc=match j{
0=>e.b1u
1=>e.b1d
2=>e.b2u
_=>e.b2d
}
return e.dev>0.0&&!mc&&(j<2?nvStd1On:kF)
}
fn lR(e:Qb,t:bool,a:bool,b:bool,c2:bool,d:bool)->Qb{
return Qb{id:e.id,code:e.code,level:e.level,startTime:e.startTime,touched:t,score:e.score,vS:e.vS,dS:e.dS,dev:e.dev,b1u:a,b1d:b,b2u:c2,b2d:d}
}
fn bl(y:float,lo:float,hi:float,cG:float)->bool{
return lo<=y+cG&&hi>=y-cG
}
fn kQ(t:time,code:string)->string{
return match code{
"4H"=>time.format(time.floor(t,4h),"{YYYY}-{MM}-{DD} {HH}:00")
"W"=>time.format(time.floor(t,1W),"{YYYY}-{MM}-{DD}")
"M"=>time.format(t,"{YYYY}-{MM}")
"Q"=>time.format(time.floor(t,3M),"{YYYY}-{MM}")
"Y"=>time.format(t,"{YYYY}")
_=>time.format(t,"{YYYY}-{MM}-{DD}")
}
}
fn mD(e:Qb)->string{
let t=match e.code{
"AS"=>O(e.startTime,ix23)
"LN"=>O(e.startTime,ix25)
"NY"=>O(e.startTime,ix27)
"NC"=>O(e.startTime,ix29)
_=>e.startTime
}
return kQ(t,e.code)
}
fn gV(e:Qb,C:string)->string{
let dy=hn?str.format("{0} · {1}",C,mD(e)):C
let lb=ix65&&!bo?str.format("{0} {1}",dy,dC(e.level)):dy
return showScores?str.format("{0} · {1}",lb,ig(e)):lb
}
fn lX(id:int){
let _=dk.delete(id)
let _=dk.delete(-id)
let _=hp.delete(id)
let _=hs.delete(id)
for j in 0..4{
let _=fo.delete(id*4+j)
}
}
fn nvN(c:string)->string{
return c=="MH"||c=="ML"?str.format("{0}{1}",hlMC,c=="MH"?"H":"L"):(c=="WH"||c=="WL"?str.format("{0}{1}",hlWC,c=="WH"?"H":"L"):c)
}
fn ko(e:Qb)->string{
return ak?gV(e,str.format("n{0} VWAP",nvN(e.code))):""
}
fn fl(e:Qb,S:time){
let x2=ix61&&!dl?time.shiftBars(e.startTime,1):S
let nP=ix58?time.shiftBars(e.startTime,1):S
dk.get(e.id).set(
x1:e.startTime,y1:e.level,x2:x2,y2:e.level,
color:nvDim&&topReady&&!jI(e.id)?color.withAlpha(bn(e.code),kD):bn(e.code),
width:ix60,style:mS,extend:mP,text:dl?"":ko(e)
)
if dl{
dk.get(-e.id).set(x1:S,y1:e.level,x2:time.shiftBars(S,1),y2:e.level,color:color.withAlpha(bn(e.code),76),width:ix60,style:a4,extend:a5,text:ko(e))
}
if nvStd1On{
let mb=nvDim&&topReady&&!jI(e.id)
for j in 0..4{
if dv(e,j){
let bc=aC(j<2?std1Color:ix5,bn(e.code))
fo.get(e.id*4+j).set(
x1:e.startTime,y1:aL(e,j),x2:nP,y2:aL(e,j),
color:color.withAlpha(bc,mb?lU(float(kD)*0.5):150),width:1.0,style:a4,extend:mO
)
}
}
}
}
fn md(e:Qb){
let B=bn(e.code)
fl(e,chart.time??e.startTime)
if ho||hr{
let cF=gV(e,str.format("n{0} VWAP",nvN(e.code)))
let y=e.level*gE
if ho{
hp.get(e.id).set(x:8.0,y:y,text:cF,color:B,size:ix63,textAlign:"right",zIndex:40)
}
if hr{
hs.get(e.id).set(x:e.startTime,y:y,text:cF,color:B,size:ix63,zIndex:40)
}
}
}
fn az(code:string,e:float,dev:float,t:time,sc:Qk){
let ha=Qb{id:nextNvId,code:code,level:e,startTime:t,touched:false,score:sc.r,vS:sc.v,dS:sc.d,dev:dev,b1u:false,b1d:false,b2u:false,b2d:false}
nextNvId+=1
if levels.len<levels.capacity{
levels.push(ha)
}else{
let ll=0
let gf=false
let ge=2147483647
for k in 0..levels.len{
let it=levels.get(k)
if it !=null{
let lV=(it.touched&&!gf)||(it.touched==gf&&it.id<ge)
if lV{
ll=k
gf=it.touched
ge=it.id
}
}
}
lX(ge)
levels.set(ll,ha)
}
md(ha)
}
type Qm{
one:bool
two:bool
three:bool
active:bool
}
type Qh{
center:bool
ring:bool
outer:bool
filled:bool
}
type Qc{
m1:float
m2:float
l:Qm
z:Qh
}
fn cP(c1:color,c2:color,en:bool,aU:bool,style:Qc,ae:bool,af:bool,ov:float?,od:float?,v:float?,d:float?,cl:PlotLine,ck:PlotLine,cn:PlotLine,cm:PlotLine,f1:Fill,dB:Fill,dA:Fill,ring:bool){
let bG=en&&v !=null&&d !=null
let lQ=style.z.center
let il=style.z.ring&&ring
let ed=bG&&(style.l.one||lQ||il)
let ee=bG&&(style.l.two||il)
let vv=v??0.0
let dd=d??0.0
let aE=ov !=null&&od !=null
let aY=ov??0.0
let odd=od??0.0
al(cl,c1,ed,aU||!style.l.one,ae,af,aE?aY+style.m1*odd:null,vv+style.m1*dd)
al(ck,c1,ed,aU||!style.l.one,ae,af,aE?aY-style.m1*odd:null,vv-style.m1*dd)
al(cn,c2,ee,aU||!style.l.two,ae,af,aE?aY+style.m2*odd:null,vv+style.m2*dd)
al(cm,c2,ee,aU||!style.l.two,ae,af,aE?aY-style.m2*odd:null,vv-style.m2*dd)
if bG&&!aU&&!ae&&!af{
if lQ{
f1.fill()
}
if il{
dB.fill()
dA.fill()
}
}
}
fn jK(key:int,av:bool,v:float?,B:color,cF:string){
if(eY||cF !="")&&key>=0&&chart.isLast{
if av&&v !=null{
let t=chart.time??time.fromUnixSeconds(0)
aF.get(-key-1).set(x1:t,y1:v??0.0,x2:time.shiftBars(t,1),y2:v??0.0,color:eY?color.withAlpha(B,76):B,width:1.0,style:a4,extend:a5,text:cF)
}else{
let _=aF.delete(-key-1)
}
}
}
fn bM(key:int,av:bool,v:float?,aK:string,B:color){
let fm=ak&&((key>=0&&key<6)||(key>=10&&key<16))
jK(key,av&&key>=0,v,B,fm?str.format("{0} {1}",aK,dC(v??0.0)):"")
if key>=0&&chart.isLast{
if av&&v !=null&&!fm{
bw.get(100+key).set(x:8.0,y:v??0.0,text:str.format("{0}  {1}",aK,dC(v??0.0)),color:B,size:11.0,textAlign:"right",zIndex:35)
}else{
let _=bw.delete(100+key)
}
}
}
fn mq(t0:time?,tn:time,jk:int,ez:bool,jn:bool,jp:bool,nv:float?,B:color,w:float,st:LineStyle){
if bX.len==0{
for i in 0..24{
dI.push(0.0)
}
for i in 0..12{
bX.push(0)
gC.push(0)
}
}
let ph=bX.get(jk)??0
let y=nv??0.0
let ok=nv !=null&&t0 !=null
let n=gC.get(jk)??0
if jn{
gC[jk]=n<1000?n+1:0
dI[jk*2]=y
bX[jk]=nv !=null?1:0
}else if jp{
if ph==1&&ok{
if ez&&t0 !=null{
aB.get(100+jk,n,0).set(x1:t0,y1:dI.get(jk*2)??y,x2:tn,y2:y,color:B,width:w,style:st,extend:K)
}
dI[jk*2+1]=y
bX[jk]=2
}else{
bX[jk]=0
}
}else if ph==2{
if ok&&ez&&t0 !=null{
aB.get(100+jk,n,1).set(x1:t0,y1:dI.get(jk*2+1)??y,x2:tn,y2:y,color:B,width:w,style:st,extend:K)
}
bX[jk]=0
}
}
fn fc(id:int,N:int,j:int,t1:time,v1:float,d1:float,t2:time,v2:float,d2:float,B:color,w:float,style:Qc){
bu.get(id,N,j,0).set(x1:t1,y1:v1,x2:t2,y2:v2,color:B,width:w,style:linestyle.solid,extend:K,zIndex:5)
if style.l.one||style.z.center{
let c1=style.l.one?color.withAlpha(B,150):invisible
let u=bu.get(id,N,j,1)
u.set(x1:t1,y1:v1+style.m1*d1,x2:t2,y2:v2+style.m1*d2,color:c1,width:1.0,style:a0,extend:K)
let dn=bu.get(id,N,j,2)
dn.set(x1:t1,y1:v1-style.m1*d1,x2:t2,y2:v2-style.m1*d2,color:c1,width:1.0,style:a0,extend:K)
if style.z.center{
dV.get(id,N,j).set(lineA:u,lineB:dn,color:color.withAlpha(B,E))
}
}
if style.l.two{
let c2=color.withAlpha(B,110)
bu.get(id,N,j,3).set(x1:t1,y1:v1+style.m2*d1,x2:t2,y2:v2+style.m2*d2,color:c2,width:1.0,style:a0,extend:K)
bu.get(id,N,j,4).set(x1:t1,y1:v1-style.m2*d1,x2:t2,y2:v2-style.m2*d2,color:c2,width:1.0,style:a0,extend:K)
}
}
fn mz(id:int,N:int,len:int,B:color,w:float,style:Qc){
if len>17{
let C=id*256
aA.clear()
aA.push(0)
aA.push(len-1)
let mC=math.max(style.l.one||style.z.center?style.m1:0.0,style.l.two?style.m2:0.0)
for cut in 0..15{
let lS=-1.0
let dx=-1
let bF=0
for seg in 0..(aA.len-1){
let lo=aA[seg]??0
let hi=aA[seg+1]??lo
let du=aW[C+lo]
let tb=aW[C+hi]
if du !=null&&tb !=null{
let lE=time.durationSeconds(time.diff(tb,du))
for j in 0..(hi-lo-1){
let cS=lo+j+1
let ti=aW[C+cS]
if lE>0&&ti !=null{
let f=float(time.durationSeconds(time.diff(ti,du)))/float(lE)
let va=aX[C+lo]??0.0
let da=aV[C+lo]??0.0
let iX=math.abs((aX[C+cS]??0.0)-va-f*((aX[C+hi]??0.0)-va))+mC*math.abs((aV[C+cS]??0.0)-da-f*((aV[C+hi]??0.0)-da))
if iX>lS{
lS=iX
dx=cS
bF=seg+1
}
}
}
}
}
if dx>=0{
aA.push(dx)
for j in 0..(aA.len-bF-1){
let k=aA.len-1-j
aA[k]=aA[k-1]??dx
}
aA[bF]=dx
}
}
let _=bu.clear(id,N)
let _=dV.clear(id,N)
for seg in 0..(aA.len-1){
let lo=aA[seg]??0
let hi=aA[seg+1]??lo
let du=aW[C+lo]
let tb=aW[C+hi]
if du !=null&&tb !=null{
fc(id,N,seg+1,du,aX[C+lo]??0.0,aV[C+lo]??0.0,tb,aX[C+hi]??0.0,aV[C+hi]??0.0,B,w,style)
}
}
let tl=aW.get(C+len-1)
let te=gS.get(id)
if tl !=null&&te !=null&&time.diff(te,tl)>0s{
fc(id,N,999,tl,aX.get(C+len-1)??0.0,aV.get(C+len-1)??0.0,te,gT.get(id)??0.0,gR.get(id)??0.0,B,w,style)
}
}
}
fn cX(id:int,lT:bool,ic:bool,mN:bool,ts:time,v:float?,d:float?,bars:float,gD:int,B:color,w:float,style:Qc,aK:string){
if fd.len==0{
for i in 0..lvSlots{
aW.push(ts)
aX.push(0.0)
aV.push(0.0)
}
for i in 0..6{
fd.push(0)
dX.push(0)
gP.push(0)
gS.push(ts)
gT.push(0.0)
gR.push(0.0)
}
}
let C=id*256
let len=fd.get(id)??0
let N=gP.get(id)??0
if ic{
mz(id,N,len,B,w,style)
let _=bu.clear(id,N-gD)
let _=dV.clear(id,N-gD)
N=N+1
len=0
}else if mN{
let _=bu.clear(id,N)
let _=dV.clear(id,N)
len=0
}
if lT&&v !=null{
let vv=v??0.0
let dd=d??0.0
let nF=math.max(1,int(math.floor(bars/float(jR)))??1)
let n=(dX.get(id)??0)+1
let hW=false
if len==0{
aW[C]=ts
aX[C]=vv
aV[C]=dd
len=1
dX[id]=0
hW=true
}else if(n>=nF||len<12)&&len<eZ{
let tA=aW.get(C+len-1)
if tA !=null{
fc(id,N,len-1,tA,aX.get(C+len-1)??vv,aV.get(C+len-1)??0.0,ts,vv,dd,B,w,style)
}
aW[C+len]=ts
aX[C+len]=vv
aV[C+len]=dd
len=len+1
dX[id]=0
hW=true
}else{
dX[id]=n
}
if hW{
let _=bu.clear(id,N,999)
let _=dV.clear(id,N,999)
}else{
let tA=aW.get(C+len-1)
if tA !=null{
fc(id,N,999,tA,aX.get(C+len-1)??vv,aV.get(C+len-1)??0.0,ts,vv,dd,B,w,style)
}
}
gS[id]=ts
gT[id]=vv
gR[id]=dd
bM(10+id,true,vv,aK,B)
}else{
bM(10+id,false,null,aK,B)
}
fd[id]=len
gP[id]=N
}
fn aN(jk:int,key:int,aK:string,B:color,en:bool,eQ:bool,br:bool,style:Qc,ae:bool,af:bool,kG:float,oV:float,mT:float,aE:bool,pv:float,v:float,p2:float,p:PlotLine,cl:PlotLine,ck:PlotLine,cn:PlotLine,cm:PlotLine,f1:Fill){
let jn=ix1&&ae
let jp=ix1&&af
let ov=bD(kG,oV,aE)
let nv=bD(pv,v,true)
al(p,B,en,eQ,jn,jp,ov,nv)
if ix1{
let jw=jk<4?2.0:1.5
let mn=jk==2||jk==3||jk==6||jk==7||jk==10||jk==11
if bY.len==2{
mq(bY.get(0),bY.get(1)??chart.time??bY.get(0)??time.fromUnixSeconds(0),jk,en&&!eQ,jn,jp,nv,B,jw,mn?a0:linestyle.solid)
}
}
bM(key,en&&!eQ,nv,aK,B)
cP(color.withAlpha(B,150),color.withAlpha(B,110),en&&br,eQ,style,jn,jp,ov,en&&br?U(kG,oV,mT,aE):null,nv,en&&br?U(pv,v,p2,true):null,cl,ck,cn,cm,f1,f1,f1,false)
}
fn eM(key:int,aK:string,B:color,av:bool,br:bool,style:Qc,bm:bool,cH:bool,nM:bool,o:Qi,n:Qi,p:PlotLine,cl:PlotLine,ck:PlotLine,cn:PlotLine,cm:PlotLine,f1:Fill,dB:Fill,dA:Fill){
let aU=!bm&&!extendSessVWAP
let ae=ix1&&bm&&!cH
let af=ix1&&cH&&!nM
let ov=o.value(cH)
let nv=n.value(bm)
al(p,B,av,aU,ae,af,ov,nv)
bM(key,av&&!aU,nv,aK,B)
cP(color.withAlpha(B,150),color.withAlpha(B,110),av&&br,aU,style,ae,af,ov,av&&br?o.dev(cH):null,nv,av&&br?n.dev(bm):null,cl,ck,cn,cm,f1,dB,dA,true)
}
fn cQ(nd:LinePool,nD:int,cS:int,t:time[],v:float[],nG:time,nJ:float,B:color,w:float){
let n=t.len
for j in 0..n{
let t1=t.get(j)
let v1=v.get(j)
let t2=j+1<n?t.get(j+1):nG
let v2=j+1<n?v.get(j+1):nJ
if t1 !=null&&v1 !=null&&t2 !=null&&v2 !=null{
nd.get(nD,cS,j).set(x1:t1,y1:v1,x2:t2,y2:v2,color:B,width:w,style:a0,extend:K)
}
}
}
fn am(ca:LinePool,eO:LineFillPool,C:int,x1:time,x2:time,dz:Extend,hv:rolling<float>,hd:rolling<float>,B:color,style:Qc){
let source=mV(C==0?"4H":C==50?"D":C==100?"W":C==150?"M":C==200?"Q":"Y")
let n=math.min(projCount,hv.len)
for k in 0..n{
let vN=hv[hv.len-1-k]
if vN !=null{
let v=vN??0.0
let d=hd[hd.len-1-k]??0.0
let a=math.max(10,80-k*6)
let fa=int(math.round(float(color.a(ix18))*math.max(0.2,1.0-float(k)/11.0)))??0
let kb=C+k*5
let fb=C+k*3
ca.get(kb).set(x1:x1,y1:v,x2:x2,y2:v,width:projWidth,color:color.withAlpha(B,a),style:a0,extend:dz)
let lu=(style.l.one||style.z.center||style.z.ring)&&d>0.0
let nx=(style.l.two||style.z.ring)&&d>0.0
if lu{
let u1=ca.get(kb+1)
let l1=ca.get(kb+2)
u1.set(x1:x1,y1:v+style.m1*d,x2:x2,y2:v+style.m1*d,width:1.0,color:style.l.one?color.withAlpha(aC(std1Color,source),a):invisible,style:a0,extend:dz)
l1.set(x1:x1,y1:v-style.m1*d,x2:x2,y2:v-style.m1*d,width:1.0,color:style.l.one?color.withAlpha(aC(std1Color,source),a):invisible,style:a0,extend:dz)
if style.z.center{
eO.get(fb).set(lineA:u1,lineB:l1,color:color.withAlpha(aC(std1Color,source),fa))
}
}
if nx{
let u2=ca.get(kb+3)
let l2=ca.get(kb+4)
u2.set(x1:x1,y1:v+style.m2*d,x2:x2,y2:v+style.m2*d,width:1.0,color:style.l.two?color.withAlpha(aC(ix5,source),a):invisible,style:a0,extend:dz)
l2.set(x1:x1,y1:v-style.m2*d,x2:x2,y2:v-style.m2*d,width:1.0,color:style.l.two?color.withAlpha(aC(ix5,source),a):invisible,style:a0,extend:dz)
if style.z.ring{
let c2=color.withAlpha(aC(ix5,source),fa)
if lu{
eO.get(fb+1).set(lineA:u2,lineB:ca.get(kb+1),color:c2)
eO.get(fb+2).set(lineA:ca.get(kb+2),lineB:l2,color:c2)
}else{
eO.get(fb+1).set(lineA:u2,lineB:l2,color:c2)
}
}
}
}
}
}
fn mF(code:string)->int{
return match code{
"4H"=>0
"D"=>1
"W"=>2
"M"=>3
"Q"=>4
"Y"=>5
"AS"=>6
"LN"=>7
"NY"=>8
"NC"=>9
"MH"=>10
"ML"=>11
"WH"=>12
"WL"=>13
"DH"=>14
_=>15
}
}
fn eB(i:int)->Qb?{
if i<levels.len{
return levels.get(i)
}
let p=pfNaked.get(i-levels.len)
if p==null{
return null
}
return Qb{id:-p.id-1,code:p.kind==0?"V":"T",level:p.price,startTime:p.birth,touched:p.touched,score:0,vS:0,dS:0,dev:0.0,b1u:true,b1d:true,b2u:true,b2d:true}
}
fn lW(px:float){
if bN.len==0{
for k in 0..48{
bN.push(-1)
}
}else{
for k in 0..48{
bN[k]=-1
}
}
for i in 0..(levels.len+(dj?pfNaked.len:0)){
let G=eB(i)
if G !=null&&!G.touched{
let C=dj?0:mF(G.code)*3
let dw=i
for k in 0..nvAxisCount{
if dw>=0{
let hu=bN[C+k]??-1
let ab=eB(hu)
let hb=eB(dw)
let kw=hb !=null?math.abs(hb.level-px):1e18
let kH=ab !=null?math.abs(ab.level-px):1e18
if hb !=null&&(ab==null||kw<kH||(kw==kH&&dw<hu)){
bN[C+k]=dw
dw=hu
}
}
}
}
}
}
fn gx(i:int,a:PlotLine,key:int,av:bool,aK:string){
let none:float?=null
if i>=0{
let it=eB(i)
if it !=null{
if(topIds[key]??-1)!=it.id{
topChanged=true
}
topIds[key]=it.id
if av{
a.plot(it.level,color:bn(it.code))
let cF=gV(it,aK)
if !bo{
bw.get(key).set(x:8.0,y:it.level*gE,text:cF,color:bn(it.code),size:ix63,textAlign:"right",zIndex:40)
}else{
let _=bw.delete(key)
}
}else{
let _=bw.delete(key)
}
return
}
}
if(topIds[key]??-1)!=-1{
topChanged=true
}
topIds[key]=-1
if av{
a.plot(none)
}
let _=bw.delete(key)
}
fn aw(code:string,C:int,av:bool,a1:PlotLine,a2:PlotLine,a3:PlotLine){
let i1=bN[C]??-1
let i2=bN[C+1]??-1
let i3=bN[C+2]??-1
gx(i1,a1,C,av,str.format("n{0} VWAP 1",code))
gx(i2,a2,C+1,av,str.format("n{0} VWAP 2",code))
gx(i3,a3,C+2,av,str.format("n{0} VWAP 3",code))
}
fn dH(row:int,text:string,B:color){
let vr=jH?row:hudN-1-row
jG.get(row).set(
x:12.0,y:12.0+float(vr)*ml,text:text,color:B,
size:hudSize,font:font.mono,textAlign:mk,zIndex:60
)
}
fn bV(row:int,aK:string,v:float?,d:float?,px:float,B:color)->int{
if v==null||v<=0.0{
return row
}
let mU=(px-v)/v*100.0
let z=d !=null&&d>0.0?(px-v)/d:0.0
dH(row,str.format("{0}  {1}  {2:+.2}%  {3:+.1}σ",aK,math.round(v,2),mU,z),B)
return row+1
}
on chart.update{
let lO=chart.time
if lO==null{
return
}
let ts=lO
let F=chart.time[1]
if jF{
mj(ts)
}
if fs{
ni(ts)
}
let oN=chart.open
let hN=chart.high
let lN=chart.low
let cN=chart.close
if oN==null||hN==null||lN==null||cN==null{
return
}
let o=oN
let h=hN
let l=lN
let c=cN
let vol=chart.volume??0.0
let ar=dt==0?(h+l+c)/3.0:(dt==1?(o+h+l+c)/4.0:(dt==2?(h+l)/2.0:c))
if firstLoaded==null{
firstLoaded=ts
}
if momentOrigin==null&&vol>0.0{
momentOrigin=ar
}
let pv=ar*vol
let iI=ar-(momentOrigin??ar)
let p2=mM?iI*iI*vol:0.0
let cI=float(math.max(1,time.durationSeconds(time.bars(1))))
let bW=time.isNewPeriod(ts,F,4h)
let aP=time.isNewPeriod(ts,F,1D)
let aJ=time.isNewPeriod(ts,F,1W)
let aI=time.isNewPeriod(ts,F,1M)
let bJ=time.isNewPeriod(ts,F,3M)
let bK=time.isNewPeriod(ts,F,1Y)
let iJ=seen4H&&F !=null
let iK=seenD&&F !=null
let iN=seenW&&F !=null
let iL=seenM&&F !=null
let iM=seenQ&&F !=null
let iO=seenY&&F !=null
let bI=q&&mE
let jC=b0
let ax=jC !=null&&time.shiftBars(jC,1,tf:4h)==time.floor(ts,4h)
if aa&&aJ&&F !=null{
lastW_V=ax?hw.value(time.floor(F,1W),false):null
lastW_D=ax?hw.value(time.floor(F,1W),true):null
}
if aa&&aI&&F !=null{
lastM_V=ax?hm.value(time.floor(F,1M),false):null
lastM_D=ax?hm.value(time.floor(F,1M),true):null
}
if aa&&bJ&&F !=null{
lastQ_V=ax?hq.value(time.floor(F,3M),false):null
lastQ_D=ax?hq.value(time.floor(F,3M),true):null
}
if aa&&bK&&F !=null{
lastY_V=ax?hy.value(time.floor(F,1Y),false):null
lastY_D=ax?hy.value(time.floor(F,1Y),true):null
}
if q&&F !=null{
if bW&&iJ&&kx&&last4H_V !=null{
az("4H",last4H_V,last4H_D??0.0,F,ay(vol4H,dlt4H,jd,jg))
}
if aP&&iK&&ky&&lastD_V !=null{
az("D",lastD_V,lastD_D??0.0,F,ay(volD,dltD,jf,ji))
}
if aJ&&iN&&kB&&lastW_V !=null{
az("W",lastW_V,lastW_D??0.0,F,ay(volW,dltW,jA,jr))
}
if aI&&iL&&kz&&lastM_V !=null{
az("M",lastM_V,lastM_D??0.0,F,ay(volM,dltM,jv,jl))
}
if bJ&&iM&&kA&&lastQ_V !=null{
az("Q",lastQ_V,lastQ_D??0.0,F,ay(volQ,dltQ,jz,jq))
}
if bK&&iO&&kC&&lastY_V !=null{
az("Y",lastY_V,lastY_D??0.0,F,ay(volY,dltY,jB,js))
}
}
if bW{
if co&&seen4H&&vol4H>0.0{
jd.push(vol4H)
jg.push(dlt4H)
}
seen4H=F !=null||ts==time.floor(ts,4h)
vol4H=0.0
dlt4H=0.0
}
if aP{
if cu&&seenD&&volD>0.0{
jf.push(volD)
ji.push(dltD)
}
seenD=F !=null||ts==time.floor(ts,1D)
volD=0.0
dltD=0.0
}
if aJ{
if cA&&seenW&&volW>0.0{
jA.push(volW)
jr.push(dltW)
}
seenW=F !=null||ts==time.floor(ts,1W)
volW=0.0
dltW=0.0
}
if aI{
if cx&&seenM&&volM>0.0{
jv.push(volM)
jl.push(dltM)
}
seenM=F !=null||ts==time.floor(ts,1M)
volM=0.0
dltM=0.0
}
if bJ{
if cz&&seenQ&&volQ>0.0{
jz.push(volQ)
jq.push(dltQ)
}
seenQ=F !=null||ts==time.floor(ts,3M)
volQ=0.0
dltQ=0.0
}
if bK{
if cB&&seenY&&volY>0.0{
jB.push(volY)
js.push(dltY)
}
seenY=F !=null||ts==time.floor(ts,1Y)
volY=0.0
dltY=0.0
}
let ix=chart.buyVolume
let lv=chart.sellVolume
let dBar=!mL?0.0:ix !=null&&lv !=null?(ix??0.0)-(lv??0.0):(h>l?vol*(c-o)/(h-l):0.0)
if co{
dlt4H+=dBar
vol4H+=vol
}
if cu{
dltD+=dBar
volD+=vol
}
if cA{
dltW+=dBar
volW+=vol
}
if cx{
dltM+=dBar
volM+=vol
}
if cz{
dltQ+=dBar
volQ+=vol
}
if cB{
dltY+=dBar
volY+=vol
}
let ey=mG?chart.vwap(reset:bW,source:ar):null
let eH=lY?chart.vwapDev(reset:bW,source:ar):null
let vD=mK?chart.vwap(reset:aP,source:ar):null
let dD=ma?chart.vwapDev(reset:aP,source:ar):null
let vW=aa?(ax?hw.value(time.floor(ts,1W),false):null):gY?chart.vwap(reset:aJ,source:ar):null
let dW=aa?(ax&&iV?hw.value(time.floor(ts,1W),true):null):iV?chart.vwapDev(reset:aJ,source:ar):null
let vM=aa?(ax?hm.value(time.floor(ts,1M),false):null):gW?chart.vwap(reset:aI,source:ar):null
let dM=aa?(ax&&iT?hm.value(time.floor(ts,1M),true):null):iT?chart.vwapDev(reset:aI,source:ar):null
let vQ=aa?(ax?hq.value(time.floor(ts,3M),false):null):gX?chart.vwap(reset:bJ,source:ar):null
let dQ=aa?(ax&&iU?hq.value(time.floor(ts,3M),true):null):iU?chart.vwapDev(reset:bJ,source:ar):null
let vY=aa?(ax?hy.value(time.floor(ts,1Y),false):null):gZ?chart.vwap(reset:bK,source:ar):null
let dY=aa?(ax&&iW?hy.value(time.floor(ts,1Y),true):null):iW?chart.vwapDev(reset:bK,source:ar):null
let pp=chart.time[2]
let ao=F !=null
let J=F??ts
let mp=ix1&&bW
let jD=ix1&&aP
let jW=ix1&&aJ
let jM=ix1&&aI
let jQ=ix1&&bJ
let jY=ix1&&bK
let mr=ix1&&ao&&time.isNewPeriod(J,pp,4h)
let ms=ix1&&ao&&time.isNewPeriod(J,pp,1D)
let mv=ix1&&ao&&time.isNewPeriod(J,pp,1W)
let mt=ix1&&ao&&time.isNewPeriod(J,pp,1M)
let mu=ix1&&ao&&time.isNewPeriod(J,pp,3M)
let mw=ix1&&ao&&time.isNewPeriod(J,pp,1Y)
cR(0,color4H,ba&&!bI,iy,bs4H,ey,eH,last4H_V,last4H_D,mp,mr,
p4h,p4h_s1u,p4h_s1d,p4h_s2u,p4h_s2d,p4h_s3u,p4h_s3d,
f4h_s1,f4h_s2u,f4h_s2d,f4h_s3)
cR(1,colorDaily,bb&&!bI,iB,bsDaily,vD,dD,lastD_V,lastD_D,jD,ms,
pd,pd_s1u,pd_s1d,pd_s2u,pd_s2d,pd_s3u,pd_s3d,
fd_s1,fd_s2u,fd_s2d,fd_s3)
cR(2,colorWeekly,bg&&!bI,iG,bsWeekly,vW,dW,lastW_V,lastW_D,jW,mv,
pw,pw_s1u,pw_s1d,pw_s2u,pw_s2d,pw_s3u,pw_s3d,
fw_s1,fw_s2u,fw_s2d,fw_s3)
cR(3,colorMonthly,bd&&!bI,iD,bsMonthly,vM,dM,lastM_V,lastM_D,jM,mt,
pm,pm_s1u,pm_s1d,pm_s2u,pm_s2d,pm_s3u,pm_s3d,
fm_s1,fm_s2u,fm_s2d,fm_s3)
cR(4,colorQuarterly,bf&&!bI,iF,bsQuarterly,vQ,dQ,lastQ_V,lastQ_D,jQ,mu,
pq,pq_s1u,pq_s1d,pq_s2u,pq_s2d,pq_s3u,pq_s3d,
fq_s1,fq_s2u,fq_s2d,fq_s3)
cR(5,colorYearly,bh&&!bI,iH,bs,vY,dY,lastY_V,lastY_D,jY,mw,
py,py_s1u,py_s1d,py_s2u,py_s2d,py_s3u,py_s3d,
fy_s1,fy_s2u,fy_s2d,fy_s3)
if !bI&&F !=null{
let pt=F??ts
if ba&&eg&&bW&&iJ&&last4H_V !=null{
let kK=ba&&eg
let lF=pjT4H
if kK&&ix17&&lF !=null{
am(dr,dq,nextProjId*50,lF??ts,pt,K,fB,fv,ix18,bs4H)
nextProjId+=1
}
fB.push(last4H_V)
fv.push(last4H_D)
pjT4H=ts
if kK{
am(aF,aQ,0,ts,time.shiftBars(ts,1),a5,fB,fv,ix18,bs4H)
}
}
if bb&&ei&&aP&&iK&&lastD_V !=null{
let kL=bb&&ei
let lG=pjTD
if kL&&ix17&&lG !=null{
am(dr,dq,nextProjId*50,lG??ts,pt,K,fC,fw,ix18,bsDaily)
nextProjId+=1
}
fC.push(lastD_V)
fw.push(lastD_D)
pjTD=ts
if kL{
am(aF,aQ,50,ts,time.shiftBars(ts,1),a5,fC,fw,ix18,bsDaily)
}
}
if bg&&em&&aJ&&iN&&lastW_V !=null{
let kO=bg&&em
let lJ=pjTW
if kO&&ix17&&lJ !=null{
am(dr,dq,nextProjId*50,lJ??ts,pt,K,fF,fz,ix18,bsWeekly)
nextProjId+=1
}
fF.push(lastW_V)
fz.push(lastW_D)
pjTW=ts
if kO{
am(aF,aQ,100,ts,time.shiftBars(ts,1),a5,fF,fz,ix18,bsWeekly)
}
}
if bd&&ej&&aI&&iL&&lastM_V !=null{
let kM=bd&&ej
let lH=pjTM
if kM&&ix17&&lH !=null{
am(dr,dq,nextProjId*50,lH??ts,pt,K,fD,fx,ix18,bsMonthly)
nextProjId+=1
}
fD.push(lastM_V)
fx.push(lastM_D)
pjTM=ts
if kM{
am(aF,aQ,150,ts,time.shiftBars(ts,1),a5,fD,fx,ix18,bsMonthly)
}
}
if bf&&ek&&bJ&&iM&&lastQ_V !=null{
let kN=bf&&ek
let lI=pjTQ
if kN&&ix17&&lI !=null{
am(dr,dq,nextProjId*50,lI??ts,pt,K,fE,fy,ix18,bsQuarterly)
nextProjId+=1
}
fE.push(lastQ_V)
fy.push(lastQ_D)
pjTQ=ts
if kN{
am(aF,aQ,200,ts,time.shiftBars(ts,1),a5,fE,fy,ix18,bsQuarterly)
}
}
if bh&&eo&&bK&&iO&&lastY_V !=null{
let kP=bh&&eo
let lK=pjTY
if kP&&ix17&&lK !=null{
am(dr,dq,nextProjId*50,lK??ts,pt,K,fG,fA,ix18,bs)
nextProjId+=1
}
fG.push(lastY_V)
fA.push(lastY_D)
pjTY=ts
if kP{
am(aF,aQ,250,ts,time.shiftBars(ts,1),a5,fG,fA,ix18,bs)
}
}
}
if !bI&&chart.isLast{
if ba&&eg&&pjT4H !=null{
am(aF,aQ,0,pjT4H??ts,ts,a5,fB,fv,ix18,bs4H)
}
if bb&&ei&&pjTD !=null{
am(aF,aQ,50,pjTD??ts,ts,a5,fC,fw,ix18,bsDaily)
}
if bg&&em&&pjTW !=null{
am(aF,aQ,100,pjTW??ts,ts,a5,fF,fz,ix18,bsWeekly)
}
if bd&&ej&&pjTM !=null{
am(aF,aQ,150,pjTM??ts,ts,a5,fD,fx,ix18,bsMonthly)
}
if bf&&ek&&pjTQ !=null{
am(aF,aQ,200,pjTQ??ts,ts,a5,fE,fy,ix18,bsQuarterly)
}
if bh&&eo&&pjTY !=null{
am(aF,aQ,250,pjTY??ts,ts,a5,fG,fA,ix18,bs)
}
}
last4H_V=ey
lastD_V=vD
lastW_V=vW
lastM_V=vM
lastQ_V=vQ
lastY_V=vY
last4H_D=eH
lastD_D=dD
lastW_D=dW
lastM_D=dM
lastQ_D=dQ
lastY_D=dY
let bO=pp??J
let eP=pp !=null
let cT=kq&&ih.contains(ts)
if kq{
let hQ=ao&&ih.contains(J)
let lx=ao&&O(ts,ix23)==O(J,ix23)
let im=hQ&&lx
let nK=eP&&ih.contains(bO)&&O(J,ix23)==O(bO,ix23)
let bx=sAsia
if hQ&&(!cT||!lx)&&bx.v>0.0&&seenAS&&cs{
if q&&hh{
az("AS",bx.pv/bx.v,eI?(U(bx.pv,bx.v,bx.p2,true)??0.0):0.0,J,ay(bx.v,dltAS,je,jh))
}
je.push(bx.v)
jh.push(dltAS)
}
sAsia.step(cT,cT&&!im,hQ,eI,pv,eI?p2:0.0,vol)
if cT{
if !im{
seenAS=ao||ts==O(ts,ix23)
dltAS=0.0
}
if cs{
dltAS+=dBar
}
}
eM(6,"Asia VWAP",ix22,es,iz,gh,cT,im,nK,bx,sAsia,pSessAsia,pSessAsia_s1u,pSessAsia_s1d,pSessAsia_s2u,pSessAsia_s2d,pSessAsia_f1,pSessAsia_f2u,pSessAsia_f2d)
}
let cV=kt&&ij.contains(ts)
if kt{
let hS=ao&&ij.contains(J)
let lz=ao&&O(ts,ix25)==O(J,ix25)
let ip=hS&&lz
let nN=eP&&ij.contains(bO)&&O(J,ix25)==O(bO,ix25)
let bA=sLondon
if hS&&(!cV||!lz)&&bA.v>0.0&&seenLN&&cw{
if q&&hk{
az("LN",bA.pv/bA.v,eK?(U(bA.pv,bA.v,bA.p2,true)??0.0):0.0,J,ay(bA.v,dltLN,ju,jj))
}
ju.push(bA.v)
jj.push(dltLN)
}
sLondon.step(cV,cV&&!ip,hS,eK,pv,eK?p2:0.0,vol)
if cV{
if !ip{
seenLN=ao||ts==O(ts,ix25)
dltLN=0.0
}
if cw{
dltLN+=dBar
}
}
eM(7,"London VWAP",ix24,eu,iC,gk,cV,ip,nN,bA,sLondon,pSessLondon,pSessLondon_s1u,pSessLondon_s1d,pSessLondon_s2u,pSessLondon_s2d,pSessLondon_f1,pSessLondon_f2u,pSessLondon_f2d)
}
let cW=ku&&ik.contains(ts)
if ku{
let hT=ao&&ik.contains(J)
let lA=ao&&O(ts,ix27)==O(J,ix27)
let iq=hT&&lA
let nO=eP&&ik.contains(bO)&&O(J,ix27)==O(bO,ix27)
let bB=sNY
if hT&&(!cW||!lA)&&bB.v>0.0&&seenNY&&cy{
if q&&hl{
az("NY",bB.pv/bB.v,eL?(U(bB.pv,bB.v,bB.p2,true)??0.0):0.0,J,ay(bB.v,dltNY,jy,jo))
}
jy.push(bB.v)
jo.push(dltNY)
}
sNY.step(cW,cW&&!iq,hT,eL,pv,eL?p2:0.0,vol)
if cW{
if !iq{
seenNY=ao||ts==O(ts,ix27)
dltNY=0.0
}
if cy{
dltNY+=dBar
}
}
eM(8,"New York VWAP",ix26,ev,iE,gl,cW,iq,nO,bB,sNY,pSessNY,pSessNY_s1u,pSessNY_s1d,pSessNY_s2u,pSessNY_s2d,pSessNY_f1,pSessNY_f2u,pSessNY_f2d)
}
let cU=kr&&ii.contains(ts)
if kr{
let hR=ao&&ii.contains(J)
let ly=ao&&O(ts,ix29)==O(J,ix29)
let io=hR&&ly
let nL=eP&&ii.contains(bO)&&O(J,ix29)==O(bO,ix29)
let bz=sClose
if hR&&(!cU||!ly)&&bz.v>0.0&&seenNC&&ct{
if q&&hj{
az("NC",bz.pv/bz.v,eJ?(U(bz.pv,bz.v,bz.p2,true)??0.0):0.0,J,ay(bz.v,dltNC,jx,jm))
}
jx.push(bz.v)
jm.push(dltNC)
}
sClose.step(cU,cU&&!io,hR,eJ,pv,eJ?p2:0.0,vol)
if cU{
if !io{
seenNC=ao||ts==O(ts,ix29)
dltNC=0.0
}
if ct{
dltNC+=dBar
}
}
eM(9,"NY Close VWAP",ix28,et,iA,gi,cU,io,nL,bz,sClose,pSessClose,pSessClose_s1u,pSessClose_s1d,pSessClose_s2u,pSessClose_s2d,pSessClose_f1,pSessClose_f2u,pSessClose_f2d)
}
let gN=float(time.tfSeconds(b8))/cI
let gO=float(time.tfSeconds(b7))/cI
let gM=86400.0/cI
let jT=math.min(eZ,(int(math.floor(gN))??1)+2)
let jU=math.min(eZ,(int(math.floor(gO))??1)+2)
let jS=math.min(eZ,(int(math.floor(gM))??1)+2)
let mA=(aO?2*jT*lvLpsM:0)+(aH?2*jU*lvLpsW:0)+(aG?2*jS*lvLpsD:0)
let gQ=float(math.max(0,1900-mA))/float(math.max(1,fe))
let jO=math.min(48,math.max(1,int(math.floor(gQ/float(2*math.min(17,jT)*lvLpsM)))??1))
let jP=math.min(48,math.max(1,int(math.floor(gQ/float(2*math.min(17,jU)*lvLpsW)))??1))
let jN=math.min(48,math.max(1,int(math.floor(gQ/float(2*math.min(17,jS)*lvLpsD)))??1))
let oM=ptM
let b5=time.isNewPeriod(ts,F,b8)
let hI=lg?c:h
let hJ=lg?c:l
if mI{
ptM.step(b5,F !=null||ts==time.floor(ts,b8),hI,hJ,h,l,pv,cM?p2:0.0,vol,cq?dBar:0.0,bC)
}
if bT&&!aO{
let fQ=math.max(1,int(math.floor(gN/200.0))??1)
if legMJoin{
let jt=legMHlt
if jt !=null&&ptM.pHiV>0.0{
aB.get(0,legMIdx,255).set(x1:jt,y1:legMHlv,x2:ts,y2:ptM.pHiPV/ptM.pHiV,color:ix35,width:2.0,style:a0,extend:K)
}
let bL=legMLlt
if bL !=null&&ptM.pLoV>0.0{
aB.get(1,legMIdx,255).set(x1:bL,y1:legMLlv,x2:ts,y2:ptM.pLoPV/ptM.pLoV,color:ix36,width:2.0,style:a0,extend:K)
}
legMJoin=false
}
if b5&&oM.full&&oM.hiV>0.0&&oM.loV>0.0&&ptM.pHiV>0.0&&ptM.pLoV>0.0{
legMIdx+=1
let eh=ptM.pHiPV/ptM.pHiV
let el=ptM.pLoPV/ptM.pLoV
cQ(aB,0,legMIdx,dL,gI,ts,eh,ix35,2.0)
cQ(aB,1,legMIdx,dN,gJ,ts,el,ix36,2.0)
legMHlt=ts
legMHlv=eh
legMLlt=ts
legMLlv=el
legMJoin=true
}
if ptM.newHi{
dL.clear()
gI.clear()
legMHn=fQ
}
if ptM.newLo{
dN.clear()
gJ.clear()
legMLn=fQ
}
legMHn+=1
legMLn+=1
if(legMHn>=fQ||dL.len<12)&&dL.len<250&&ptM.hiV>0.0{
dL.push(ts)
gI.push(ptM.hiPV/ptM.hiV)
legMHn=0
}
if(legMLn>=fQ||dN.len<12)&&dN.len<250&&ptM.loV>0.0{
dN.push(ts)
gJ.push(ptM.loPV/ptM.loV)
legMLn=0
}
}
if ap&&aO{
cX(0,ptM.full,b5,ptM.newHi,ts,bD(ptM.hiPV,ptM.hiV,true),cM?U(ptM.hiPV,ptM.hiV,ptM.hiP2,true):null,gN,jO,ix32,2.0,bj,str.format("{0} High AVWAP",hlMC))
cX(1,ptM.full,b5,ptM.newLo,ts,bD(ptM.loPV,ptM.loV,true),cM?U(ptM.loPV,ptM.loV,ptM.loP2,true):null,gN,jO,ix33,2.0,bj,str.format("{0} Low AVWAP",hlMC))
}
if cq&&b5&&oM.hiV>0.0&&oM.loV>0.0{
if oM.hasPH&&!oM.usedPH&&oM.pHiV>0.0{
if q&&hf{
az("MH",oM.pHiPV/oM.pHiV,cM?(U(oM.pHiPV,oM.pHiV,oM.pHiP2,true)??0.0):0.0,J,ay(oM.pHiV,oM.pHiD,eS,eW))
}
eS.push(oM.pHiV)
eW.push(oM.pHiD)
}
if oM.hasPL&&!oM.usedPL&&oM.pLoV>0.0{
if q&&hf{
az("ML",oM.pLoPV/oM.pLoV,cM?(U(oM.pLoPV,oM.pLoV,oM.pLoP2,true)??0.0):0.0,J,ay(oM.pLoV,oM.pLoD,eS,eW))
}
eS.push(oM.pLoV)
eW.push(oM.pLoD)
}
}
bY.clear()
bY.push(F??ts)
bY.push(ts)
aN(0,ak&&!ap?10:-1,str.format("{0} High AVWAP",hlMC),ix32,aO&&ptM.full&&!ap,false,fV,bj,ptM.newHi,ptM.pNewHi,oM.hiPV,oM.hiV,oM.hiP2,true,ptM.hiPV,ptM.hiV,ptM.hiP2,pMHigh,pMHigh_s1u,pMHigh_s1d,pMHigh_s2u,pMHigh_s2d,pMHigh_f1)
aN(1,ak&&!ap?11:-1,str.format("{0} Low AVWAP",hlMC),ix33,aO&&ptM.full&&!ap,false,fV,bj,ptM.newLo,ptM.pNewLo,oM.loPV,oM.loV,oM.loP2,true,ptM.loPV,ptM.loV,ptM.loP2,pMLow,pMLow_s1u,pMLow_s1d,pMLow_s2u,pMLow_s2d,pMLow_f1)
aN(2,0,str.format("p{0} High AVWAP",hlMC),ix35,bT&&ptM.hasPH,bC&&oM.usedPH&&!ptM.newPH,fX,eD,ptM.newPH,ptM.pNewPH,oM.pHiPV,oM.pHiV,oM.pHiP2,oM.hasPH,ptM.pHiPV,ptM.pHiV,ptM.pHiP2,pPrevMHigh,pPrevMHigh_s1u,pPrevMHigh_s1d,pPrevMHigh_s2u,pPrevMHigh_s2d,pPrevMHigh_f1)
aN(3,1,str.format("p{0} Low AVWAP",hlMC),ix36,bT&&ptM.hasPL,bC&&oM.usedPL&&!ptM.newPL,fX,eD,ptM.newPL,ptM.pNewPL,oM.pLoPV,oM.pLoV,oM.pLoP2,oM.hasPL,ptM.pLoPV,ptM.pLoV,ptM.pLoP2,pPrevMLow,pPrevMLow_s1u,pPrevMLow_s1d,pPrevMLow_s2u,pPrevMLow_s2d,pPrevMLow_f1)
let oW=ptW
let b4=time.isNewPeriod(ts,F,b7)
if mJ{
ptW.step(b4,F !=null||ts==time.floor(ts,b7),hI,hJ,h,l,pv,cO?p2:0.0,vol,cr?dBar:0.0,bC)
}
if bU&&!aH{
let fR=math.max(1,int(math.floor(gO/200.0))??1)
if legWJoin{
let jt=legWHlt
if jt !=null&&ptW.pHiV>0.0{
aB.get(2,legWIdx,255).set(x1:jt,y1:legWHlv,x2:ts,y2:ptW.pHiPV/ptW.pHiV,color:ix40,width:1.5,style:a0,extend:K)
}
let bL=legWLlt
if bL !=null&&ptW.pLoV>0.0{
aB.get(3,legWIdx,255).set(x1:bL,y1:legWLlv,x2:ts,y2:ptW.pLoPV/ptW.pLoV,color:ix41,width:1.5,style:a0,extend:K)
}
legWJoin=false
}
if b4&&oW.full&&oW.hiV>0.0&&oW.loV>0.0&&ptW.pHiV>0.0&&ptW.pLoV>0.0{
legWIdx+=1
let eh=ptW.pHiPV/ptW.pHiV
let el=ptW.pLoPV/ptW.pLoV
cQ(aB,2,legWIdx,dT,gK,ts,eh,ix40,1.5)
cQ(aB,3,legWIdx,dU,gL,ts,el,ix41,1.5)
legWHlt=ts
legWHlv=eh
legWLlt=ts
legWLlv=el
legWJoin=true
}
if ptW.newHi{
dT.clear()
gK.clear()
legWHn=fR
}
if ptW.newLo{
dU.clear()
gL.clear()
legWLn=fR
}
legWHn+=1
legWLn+=1
if(legWHn>=fR||dT.len<12)&&dT.len<250&&ptW.hiV>0.0{
dT.push(ts)
gK.push(ptW.hiPV/ptW.hiV)
legWHn=0
}
if(legWLn>=fR||dU.len<12)&&dU.len<250&&ptW.loV>0.0{
dU.push(ts)
gL.push(ptW.loPV/ptW.loV)
legWLn=0
}
}
if ap&&aH{
cX(2,ptW.full,b4,ptW.newHi,ts,bD(ptW.hiPV,ptW.hiV,true),cO?U(ptW.hiPV,ptW.hiV,ptW.hiP2,true):null,gO,jP,ix37,1.5,bk,str.format("{0} High AVWAP",hlWC))
cX(3,ptW.full,b4,ptW.newLo,ts,bD(ptW.loPV,ptW.loV,true),cO?U(ptW.loPV,ptW.loV,ptW.loP2,true):null,gO,jP,ix38,1.5,bk,str.format("{0} Low AVWAP",hlWC))
}
if cr&&b4&&oW.hiV>0.0&&oW.loV>0.0{
if oW.hasPH&&!oW.usedPH&&oW.pHiV>0.0{
if q&&hg{
az("WH",oW.pHiPV/oW.pHiV,cO?(U(oW.pHiPV,oW.pHiV,oW.pHiP2,true)??0.0):0.0,J,ay(oW.pHiV,oW.pHiD,eT,eX))
}
eT.push(oW.pHiV)
eX.push(oW.pHiD)
}
if oW.hasPL&&!oW.usedPL&&oW.pLoV>0.0{
if q&&hg{
az("WL",oW.pLoPV/oW.pLoV,cO?(U(oW.pLoPV,oW.pLoV,oW.pLoP2,true)??0.0):0.0,J,ay(oW.pLoV,oW.pLoD,eT,eX))
}
eT.push(oW.pLoV)
eX.push(oW.pLoD)
}
}
aN(4,ak&&!ap?12:-1,str.format("{0} High AVWAP",hlWC),ix37,aH&&ptW.full&&!ap,false,gc,bk,ptW.newHi,ptW.pNewHi,oW.hiPV,oW.hiV,oW.hiP2,true,ptW.hiPV,ptW.hiV,ptW.hiP2,pWHigh,pWHigh_s1u,pWHigh_s1d,pWHigh_s2u,pWHigh_s2d,pWHigh_f1)
aN(5,ak&&!ap?13:-1,str.format("{0} Low AVWAP",hlWC),ix38,aH&&ptW.full&&!ap,false,gc,bk,ptW.newLo,ptW.pNewLo,oW.loPV,oW.loV,oW.loP2,true,ptW.loPV,ptW.loV,ptW.loP2,pWLow,pWLow_s1u,pWLow_s1d,pWLow_s2u,pWLow_s2d,pWLow_f1)
aN(6,2,str.format("p{0} High AVWAP",hlWC),ix40,bU&&ptW.hasPH,bC&&oW.usedPH&&!ptW.newPH,fY,eE,ptW.newPH,ptW.pNewPH,oW.pHiPV,oW.pHiV,oW.pHiP2,oW.hasPH,ptW.pHiPV,ptW.pHiV,ptW.pHiP2,pPrevWHigh,pPrevWHigh_s1u,pPrevWHigh_s1d,pPrevWHigh_s2u,pPrevWHigh_s2d,pPrevWHigh_f1)
aN(7,3,str.format("p{0} Low AVWAP",hlWC),ix41,bU&&ptW.hasPL,bC&&oW.usedPL&&!ptW.newPL,fY,eE,ptW.newPL,ptW.pNewPL,oW.pLoPV,oW.pLoV,oW.pLoP2,oW.hasPL,ptW.pLoPV,ptW.pLoV,ptW.pLoP2,pPrevWLow,pPrevWLow_s1u,pPrevWLow_s1d,pPrevWLow_s2u,pPrevWLow_s2d,pPrevWLow_f1)
let oD=ptD
if mH{
ptD.step(aP,F !=null||ts==time.floor(ts,1D),hI,hJ,h,l,pv,cL?p2:0.0,vol,cp?dBar:0.0,bC)
}
if bS&&!aG{
let fP=math.max(1,int(math.floor(86400.0/cI/200.0))??1)
if legDJoin{
let jt=legDHlt
if jt !=null&&ptD.pHiV>0.0{
aB.get(4,legDIdx,255).set(x1:jt,y1:legDHlv,x2:ts,y2:ptD.pHiPV/ptD.pHiV,color:ix45,width:1.5,style:a0,extend:K)
}
let bL=legDLlt
if bL !=null&&ptD.pLoV>0.0{
aB.get(5,legDIdx,255).set(x1:bL,y1:legDLlv,x2:ts,y2:ptD.pLoPV/ptD.pLoV,color:ix46,width:1.5,style:a0,extend:K)
}
legDJoin=false
}
if aP&&oD.full&&oD.hiV>0.0&&oD.loV>0.0&&ptD.pHiV>0.0&&ptD.pLoV>0.0{
legDIdx+=1
let eh=ptD.pHiPV/ptD.pHiV
let el=ptD.pLoPV/ptD.pLoV
cQ(aB,4,legDIdx,dJ,gG,ts,eh,ix45,1.5)
cQ(aB,5,legDIdx,dK,gH,ts,el,ix46,1.5)
legDHlt=ts
legDHlv=eh
legDLlt=ts
legDLlv=el
legDJoin=true
}
if ptD.newHi{
dJ.clear()
gG.clear()
legDHn=fP
}
if ptD.newLo{
dK.clear()
gH.clear()
legDLn=fP
}
legDHn+=1
legDLn+=1
if(legDHn>=fP||dJ.len<12)&&dJ.len<250&&ptD.hiV>0.0{
dJ.push(ts)
gG.push(ptD.hiPV/ptD.hiV)
legDHn=0
}
if(legDLn>=fP||dK.len<12)&&dK.len<250&&ptD.loV>0.0{
dK.push(ts)
gH.push(ptD.loPV/ptD.loV)
legDLn=0
}
}
if ap&&aG{
cX(4,ptD.full,aP,ptD.newHi,ts,bD(ptD.hiPV,ptD.hiV,true),cL?U(ptD.hiPV,ptD.hiV,ptD.hiP2,true):null,gM,jN,ix42,1.5,bi,"D High AVWAP")
cX(5,ptD.full,aP,ptD.newLo,ts,bD(ptD.loPV,ptD.loV,true),cL?U(ptD.loPV,ptD.loV,ptD.loP2,true):null,gM,jN,ix43,1.5,bi,"D Low AVWAP")
}
if cp&&aP&&oD.hiV>0.0&&oD.loV>0.0{
if oD.hasPH&&!oD.usedPH&&oD.pHiV>0.0{
if q&&he{
az("DH",oD.pHiPV/oD.pHiV,cL?(U(oD.pHiPV,oD.pHiV,oD.pHiP2,true)??0.0):0.0,J,ay(oD.pHiV,oD.pHiD,eR,eV))
}
eR.push(oD.pHiV)
eV.push(oD.pHiD)
}
if oD.hasPL&&!oD.usedPL&&oD.pLoV>0.0{
if q&&he{
az("DL",oD.pLoPV/oD.pLoV,cL?(U(oD.pLoPV,oD.pLoV,oD.pLoP2,true)??0.0):0.0,J,ay(oD.pLoV,oD.pLoD,eR,eV))
}
eR.push(oD.pLoV)
eV.push(oD.pLoD)
}
}
aN(8,ak&&!ap?14:-1,"D High AVWAP",ix42,aG&&ptD.full&&!ap,false,fU,bi,ptD.newHi,ptD.pNewHi,oD.hiPV,oD.hiV,oD.hiP2,true,ptD.hiPV,ptD.hiV,ptD.hiP2,pDHigh,pDHigh_s1u,pDHigh_s1d,pDHigh_s2u,pDHigh_s2d,pDHigh_f1)
aN(9,ak&&!ap?15:-1,"D Low AVWAP",ix43,aG&&ptD.full&&!ap,false,fU,bi,ptD.newLo,ptD.pNewLo,oD.loPV,oD.loV,oD.loP2,true,ptD.loPV,ptD.loV,ptD.loP2,pDLow,pDLow_s1u,pDLow_s1d,pDLow_s2u,pDLow_s2d,pDLow_f1)
aN(10,4,"pD High AVWAP",ix45,bS&&ptD.hasPH,bC&&oD.usedPH&&!ptD.newPH,fW,eC,ptD.newPH,ptD.pNewPH,oD.pHiPV,oD.pHiV,oD.pHiP2,oD.hasPH,ptD.pHiPV,ptD.pHiV,ptD.pHiP2,pPrevDHigh,pPrevDHigh_s1u,pPrevDHigh_s1d,pPrevDHigh_s2u,pPrevDHigh_s2d,pPrevDHigh_f1)
aN(11,5,"pD Low AVWAP",ix46,bS&&ptD.hasPL,bC&&oD.usedPL&&!ptD.newPL,fW,eC,ptD.newPL,ptD.pNewPL,oD.pLoPV,oD.pLoV,oD.pLoP2,oD.hasPL,ptD.pLoPV,ptD.pLoV,ptD.pLoP2,pPrevDLow,pPrevDLow_s1u,pPrevDLow_s1d,pPrevDLow_s2u,pPrevDLow_s2d,pPrevDLow_f1)
let gd=time.year(ts)*1000000+time.month(ts)*10000+time.dayOfMonth(ts)*100+time.hour(ts)
if ix53&&firstLoaded==ts&&(gd>gs||(gd==gs&&ts !=time.floor(ts,1h))){
customPartial=true
}
let gr=ix53&&!custAnchored&&gd>=gs
if gr{
custAnchored=true
}
let cv=ix53?chart.vwap(reset:gr,source:ar):null
let cd=lZ?chart.vwapDev(reset:gr,source:ar):null
let eG=ix53&&custAnchored&&cv !=null
pCustom.plot(eG?cv:null)
cP(color.withAlpha(ix54,150),color.withAlpha(ix54,110),eG&&iQ,false,gj,false,false,null,null,cv,cd,pCust_s1u,pCust_s1d,pCust_s2u,pCust_s2d,pCust_f1,pCust_f2u,pCust_f2d,true)
if cC{
r1.step(ts,np,nk,pv,gu?p2:0.0,vol)
}
let lh=cC?r1.value():null
pr1.plot(lh)
cP(fM,ep,cC&&fZ,false,gm,false,false,null,null,lh,gu?r1.dev():null,pr1_s1u,pr1_s1d,pr1_s2u,pr1_s2d,pr1_f1,pr1_f2u,pr1_f2d,true)
if cD{
r2.step(ts,nq,nm,pv,gv?p2:0.0,vol)
}
let li=cD?r2.value():null
pr2.plot(li)
cP(fN,eq,cD&&ga,false,gn,false,false,null,null,li,gv?r2.dev():null,pr2_s1u,pr2_s1d,pr2_s2u,pr2_s2d,pr2_f1,pr2_f2u,pr2_f2d,true)
if cE{
r3.step(ts,nr,nn,pv,gw?p2:0.0,vol)
}
let lj=cE?r3.value():null
pr3.plot(lj)
cP(fO,er,cE&&gb,false,gp,false,false,null,null,lj,gw?r3.dev():null,pr3_s1u,pr3_s1d,pr3_s2u,pr3_s2d,pr3_f1,pr3_f2u,pr3_f2d,true)
let a7:float?=null
let a8:float?=null
if q{
let ew=fT?math.max(o,c):h
let ex=fT?math.min(o,c):l
let kS=chart.close[1]
let pc=kS??o
let dE=math.max(pc,o)
let dF=math.min(pc,o)
let pT=F??ts
for i in 0..levels.len{
let I=levels.get(i)
let iw=I==null||!nA||match I.code{
"AS"=>cT
"LN"=>cV
"NY"=>cW
"NC"=>cU
_=>true
}
let dG=ix10&&kS !=null&&I !=null&&I.startTime<pT
if I !=null&&iw&&nvStd1On&&I.dev>0.0{
let bP=I.level*fS
let h0=dv(I,0)&&(bl(aL(I,0),ex,ew,bP)||(dG&&bl(aL(I,0),dF,dE,bP)))
let h1=dv(I,1)&&(bl(aL(I,1),ex,ew,bP)||(dG&&bl(aL(I,1),dF,dE,bP)))
let h2=dv(I,2)&&(bl(aL(I,2),ex,ew,bP)||(dG&&bl(aL(I,2),dF,dE,bP)))
let h3=dv(I,3)&&(bl(aL(I,3),ex,ew,bP)||(dG&&bl(aL(I,3),dF,dE,bP)))
if h0||h1||h2||h3{
let mh=[h0,h1,h2,h3]
for j in 0..4{
if mh[j]??false{
if jc{
let _=fo.delete(I.id*4+j)
}else{
let bc=aC(j<2?std1Color:ix5,bn(I.code))
fo.get(I.id*4+j).set(
x1:I.startTime,y1:aL(I,j),x2:ts,y2:aL(I,j),
color:color.withAlpha(bc,70),width:1.0,style:a4,extend:K
)
}
}
}
levels.set(i,lR(I,I.touched,I.b1u||h0,I.b1d||h1,I.b2u||h2,I.b2d||h3))
}
}
let cK=levels.get(i)
if cK !=null&&iw&&!cK.touched{
let e=cK
let cG=e.level*fS
let mg=dG&&dF<=e.level+cG&&dE>=e.level-cG
if(ex<=e.level+cG&&ew>=e.level-cG)||mg{
levels.set(i,lR(e,true,e.b1u,e.b1d,e.b2u,e.b2d))
let _=hp.delete(e.id)
let _=hs.delete(e.id)
let _=dk.delete(e.id)
let _=dk.delete(-e.id)
if !jc{
let hc=eU?color.withAlpha(bn(e.code),50+e.score*2):iR
let hw=eU?0.8+float(e.score)/40.0:1.0
mQ.get(e.id).set(
x1:e.startTime,y1:e.level,x2:ts,y2:e.level,
color:hc,width:hw,style:eU?linestyle.solid:a4,extend:K
)
if ix56{
mR.get(e.id).set(x:ts,y:e.level*gE,text:ig(e),color:eU?nB(e):iR,size:math.max(8.0,ix63-2.0),zIndex:30)
}
}
if ix12{
nakedTouched.trigger(Qn{
period:e.code,
level:e.level,
score:e.score,
message:str.format("Naked VWAP {0} mitigated at {1} ({2})",nvN(e.code),dC(e.level),ig(e)),
})
}
}else{
if kE&&chart.isLast{
fl(e,ts)
}
if e.level>c{
a7=a7==null?e.level:math.min(a7??e.level,e.level)
}else{
a8=a8==null?e.level:math.max(a8??e.level,e.level)
}
}
}else if cK !=null&&!cK.touched&&kE&&chart.isLast{
fl(cK,ts)
}
}
}
if(q||(cj&&dj))&&(aq||nvDim)&&chart.isLast{
if topIds.len==0{
for k in 0..48{
topIds.push(-1)
}
}
lW(c)
topChanged=false
aw("4H",0,aq,nvAx4H_1,nvAx4H_2,nvAx4H_3)
aw("D",3,aq,nvAxD_1,nvAxD_2,nvAxD_3)
aw("W",6,aq,nvAxW_1,nvAxW_2,nvAxW_3)
aw("M",9,aq,nvAxM_1,nvAxM_2,nvAxM_3)
aw("Q",12,aq,nvAxQ_1,nvAxQ_2,nvAxQ_3)
aw("Y",15,aq,nvAxY_1,nvAxY_2,nvAxY_3)
aw("AS",18,aq,nvAxAS_1,nvAxAS_2,nvAxAS_3)
aw("LN",21,aq,nvAxLN_1,nvAxLN_2,nvAxLN_3)
aw("NY",24,aq,nvAxNY_1,nvAxNY_2,nvAxNY_3)
aw("NC",27,aq,nvAxNC_1,nvAxNC_2,nvAxNC_3)
aw("MH",30,aq,nvAxMH_1,nvAxMH_2,nvAxMH_3)
aw("ML",33,aq,nvAxML_1,nvAxML_2,nvAxML_3)
aw("WH",36,aq,nvAxWH_1,nvAxWH_2,nvAxWH_3)
aw("WL",39,aq,nvAxWL_1,nvAxWL_2,nvAxWL_3)
aw("DH",42,aq,nvAxDH_1,nvAxDH_2,nvAxDH_3)
aw("DL",45,aq,nvAxDL_1,nvAxDL_2,nvAxDL_3)
let refresh=!topReady||topChanged
topReady=true
if nvDim&&refresh{
for i in 0..levels.len{
let e=levels.get(i)
if e !=null&&!e.touched{
fl(e,ts)
}
}
}
}
if ix68 !="Off"||ix70 !="Off"{
ne(ts,F,chart.time[2],c)
}
if ix70 !="Off"{
nj(ts,F,chart.time[2])
}
if cj{
nf(ts,o,h,l,c,F,chart.close[1])
}
if ix12{
let a6:float?=match ix13{
"4H"=>ey
"Daily"=>vD
"Weekly"=>vW
"Monthly"=>vM
"Quarterly"=>vQ
_=>vY
}
let b3:float?=match ix13{
"4H"=>eH
"Daily"=>dD
"Weekly"=>dW
"Monthly"=>dM
"Quarterly"=>dQ
_=>dY
}
let hP=chart.close[1]
let hB=prevRefV
let ib=match ix13{
"4H"=>bW
"Daily"=>aP
"Weekly"=>aJ
"Monthly"=>aI
"Quarterly"=>bJ
_=>bK
}
if(alertAcrossReset||!ib)&&a6 !=null&&hB !=null&&hP !=null{
if hP<=hB&&c>a6{
vwapCrossUp.trigger(Qd{period:ix13,price:c,vwap:a6,message:str.format("Close {0} crosses above VWAP {1} ({2})",c,ix13,math.round(a6,2))})
}
if hP>=hB&&c<a6{
vwapCrossDown.trigger(Qd{period:ix13,price:c,vwap:a6,message:str.format("Close {0} crosses below VWAP {1} ({2})",c,ix13,math.round(a6,2))})
}
}
if a6 !=null&&b3 !=null&&b3>0.0{
let up=a6+eA*b3
let dn=a6-eA*b3
let ir=h>=up
let cJ=l<=dn
if ir&&(ix14=="Every bar"||!prevBandUpper||ib){
bandUpper.trigger(Qd{period:ix13,price:h,vwap:a6,message:str.format("High {0} reaches +{1}σ of VWAP {2}",h,eA,ix13)})
}
if cJ&&(ix14=="Every bar"||!prevBandLower||ib){
bandLower.trigger(Qd{period:ix13,price:l,vwap:a6,message:str.format("Low {0} reaches -{1}σ of VWAP {2}",l,eA,ix13)})
}
prevBandUpper=ir
prevBandLower=cJ
}else{
prevBandUpper=false
prevBandLower=false
}
prevRefV=a6
}
if ix11&&chart.isLast{
let hV=do?g.rank(c):null
let one=1
hudN=1+(ba&&(ey??0.0)>0.0?one:0)+(bb&&(vD??0.0)>0.0?one:0)+(bg&&(vW??0.0)>0.0?one:0)+(bd&&(vM??0.0)>0.0?one:0)+(bf&&(vQ??0.0)>0.0?one:0)+(bh&&(vY??0.0)>0.0?one:0)+(ix53&&eG&&(cv??0.0)>0.0?one:0)+(q&&a7 !=null?one:0)+(q&&a8 !=null?one:0)+(hV !=null?one:0)
dH(0,jE?(aa?"HTF 4H · missing = incomplete":"HTF unsupported: chart"):"VWAP      LEVEL     DIST     Z",color.gray)
let r=1
if ba{
r=bV(r,seen4H?"4H":"4H*",ey,eH,c,color4H)
}
if bb{
r=bV(r,seenD?"D ":"D*",vD,dD,c,colorDaily)
}
if bg{
r=bV(r,aa?"W4h":(seenW?"W ":"W*"),vW,dW,c,colorWeekly)
}
if bd{
r=bV(r,aa?"M4h":(seenM?"M ":"M*"),vM,dM,c,colorMonthly)
}
if bf{
r=bV(r,aa?"Q4h":(seenQ?"Q ":"Q*"),vQ,dQ,c,colorQuarterly)
}
if bh{
r=bV(r,aa?"Y4h":(seenY?"Y ":"Y*"),vY,dY,c,colorYearly)
}
if ix53{
r=bV(r,customPartial?"AV*":"AV",eG?cv:null,cd,c,ix54)
}
if q{
let up=a7
let dn=a8
if up !=null{
dH(r,str.format("NV ▲  {0}  {1:+.2}%",math.round(up,2),(up-c)/c*100.0),color.withAlpha(color.red,220))
r+=1
}
if dn !=null{
dH(r,str.format("NV ▼  {0}  {1:+.2}%",math.round(dn,2),(dn-c)/c*100.0),color.withAlpha(color.green,220))
r+=1
}
}
if hV !=null{
let last=g.last
let full=g.full&&last !=null&&time.shiftBars(last,1,tf:bp)==time.floor(ts,bp)
dH(r,str.format("{0} current Vol≤Px{1} {2:.1}%",ix67,full?"":"*",hV),pfVColor)
r+=1
}
for k in r..16{
let _=jG.delete(k)
}
}
}
fn cR(key:int,B:color,ez:bool,br:bool,style:Qc,v:float?,d:float?,ov:float?,od:float?,ae:bool,af:bool,au:PlotLine,cl:PlotLine,ck:PlotLine,cn:PlotLine,cm:PlotLine,nz:PlotLine,ny:PlotLine,f1:Fill,dB:Fill,dA:Fill,f3:Fill){
jK(110+key,ez,v,B,"")
let jL=ez&&v !=null
al(au,B,jL,false,ae,af,ov,v)
let bG=jL&&br&&d !=null
let iY=style.z.center
let gy=style.z.ring
let iZ=style.z.outer
let ed=bG&&(style.l.one||iY||gy)
let ee=bG&&(style.l.two||gy)
let kp=bG&&(style.l.three||iZ)
let vv=v??0.0
let dd=d??0.0
let aE=ov !=null&&od !=null
let aY=ov??0.0
let odd=od??0.0
al(cl,aC(std1Color,B),ed,!style.l.one,ae,af,aE?aY+style.m1*odd:null,vv+style.m1*dd)
al(ck,aC(std1Color,B),ed,!style.l.one,ae,af,aE?aY-style.m1*odd:null,vv-style.m1*dd)
al(cn,aC(ix5,B),ee,!style.l.two,ae,af,aE?aY+style.m2*odd:null,vv+style.m2*dd)
al(cm,aC(ix5,B),ee,!style.l.two,ae,af,aE?aY-style.m2*odd:null,vv-style.m2*dd)
al(nz,aC(ix8,B),kp,!style.l.three,ae,af,aE?aY+ix7*odd:null,vv+ix7*dd)
al(ny,aC(ix8,B),kp,!style.l.three,ae,af,aE?aY-ix7*odd:null,vv-ix7*dd)
if bG&&!ae&&!af{
if iY{
f1.fill()
}
if gy{
dB.fill()
dA.fill()
}
if iZ{
f3.fill()
}
}
}
plot pfV=plot.line(title:str.format("{0} VPOC · confirmed",ix67),color:pfVColor,width:ix73)
plot pfT=plot.line(title:str.format("{0} TPOC · confirmed",ix67),color:ix72,width:ix73,style:a0)
plot pfPV=plot.line(title:str.format("Previous {0} VPOC",ix67),color:color.withAlpha(pfVColor,130),width:ix73)
plot pfPT=plot.line(title:str.format("Previous {0} TPOC",ix67),color:color.withAlpha(ix72,130),width:ix73,style:a0)
type Qj{
volume:float
tpo:int
last:time
}
type Qa{
lo:float?
hi:float?
}
type Qo{
rows:map<int,Qj>
keys:int[]
prefix:float[]
dirty:bool
totalV:float
totalT:float
vaV:Qa
vaT:Qa
oldVaV:Qa
oldVaT:Qa
period:time?
last:time?
started:bool
full:bool
bad:bool
rowSize:float
vp:float?
tp:float?
maxV:float
maxT:int
previous:time?
previousV:float?
previousT:float?
previousFull:bool
fn begin(p:time){
if self.period==null||self.period !=p{
self.previous=self.period
self.previousV=self.bad?null:self.vp
self.previousT=self.bad?null:self.tp
let last=self.last
self.previousFull=self.full&&last !=null&&time.shiftBars(last,1,tf:bp)==p
self.oldVaV=self.bad?Qa{lo:null,hi:null}:self.vaV
self.oldVaT=self.bad?Qa{lo:null,hi:null}:self.vaT
self.keys.clear()
self.prefix.clear()
self.dirty=true
self.totalV=0.0
self.totalT=0.0
self.vaV=Qa{lo:null,hi:null}
self.vaT=Qa{lo:null,hi:null}
self.rows.clear()
self.period=p
self.started=false
self.full=false
self.bad=false
self.rowSize=0.0
self.vp=null
self.tp=null
self.maxV=0.0
self.maxT=0
}
}
fn add(price:float,volume:float,aj:time){
if !self.bad&&volume>0.0{
let key=int(math.floor(price/self.rowSize))
if key==null{
self.bad=true
return
}
let ab=self.rows.get(key)
if ab==null&&self.rows.len>=4096{
self.bad=true
return
}
if fr{
self.dirty=true
if ab==null{
self.insertKey(key)
}
}
let value=(ab !=null?ab.volume:0.0)+(kV?volume:0.0)
let count=(ab !=null?ab.tpo:0)+(kU&&(ab==null||ab.last !=aj)?1:0)
self.rows.set(key,Qj{volume:value,tpo:count,last:aj})
let center=(float(key)+0.5)*self.rowSize
if kV&&(value>self.maxV||(value==self.maxV&&(self.vp==null||center<self.vp))){
self.maxV=value
self.vp=center
}
if kU&&(count>self.maxT||(count==self.maxT&&(self.tp==null||center<self.tp))){
self.maxT=count
self.tp=center
}
}
}
fn insertKey(key:int){
let lM=self.keys.last()
if lM==null||key>lM{
self.keys.push(key)
return
}
let lo=0
let hi=self.keys.len
for k in 0..13{
if lo<hi{
let au=int(math.floor(float(lo+hi)/2.0))??lo
if(self.keys[au]??key)<key{
lo=au+1
}else{
hi=au
}
}
}
self.keys.push(key)
for k in 0..(self.keys.len-lo-1){
let j=self.keys.len-1-k
self.keys[j]=self.keys[j-1]??key
}
self.keys[lo]=key
}
fn area(total:float,kZ:float?,volume:bool)->Qa{
let bR=Qa{lo:null,hi:null}
if self.bad||total<=0.0||kZ==null||self.keys.len==0{
return bR
}
let key=int(math.floor(kZ/self.rowSize))
if key==null{
return bR
}
let lo=0
let hi=self.keys.len
for k in 0..13{
if lo<hi{
let au=int(math.floor(float(lo+hi)/2.0))??lo
if(self.keys[au]??key)<key{
lo=au+1
}else{
hi=au
}
}
}
let gF=lo
let right=lo
let row=self.rows.get(key)
let gq=row !=null?(volume?row.volume:float(row.tpo)):0.0
let nH=total*pfVaPct/100.0
for k in 0..self.keys.len{
if gq<nH{
let lk=self.keys[gF-1]
let rk=self.keys[right+1]
let lr=lk !=null?self.rows.get(lk):null
let rr=rk !=null?self.rows.get(rk):null
let lw=lr !=null?(volume?lr.volume:float(lr.tpo)):-1.0
let rw=rr !=null?(volume?rr.volume:float(rr.tpo)):-1.0
if lk !=null&&(rk==null||lw>=rw){
gF-=1
gq+=lw
}else if rk !=null{
right+=1
gq+=rw
}
}
}
return Qa{lo:float(self.keys[gF]??key)*self.rowSize,hi:(float(self.keys[right]??key)+1.0)*self.rowSize}
}
fn refresh(){
if self.dirty||self.bad{
self.dirty=false
self.prefix.clear()
self.totalV=0.0
self.totalT=0.0
self.vaV=Qa{lo:null,hi:null}
self.vaT=Qa{lo:null,hi:null}
if !self.bad{
for k in 0..self.keys.len{
let key=self.keys[k]
if key !=null{
let row=self.rows.get(key)
if row !=null{
self.totalV+=row.volume
self.totalT+=float(row.tpo)
}
}
if do{
self.prefix.push(self.totalV)
}
}
if fu{
self.vaV=self.area(self.totalV,self.vp,true)
}
if ft{
self.vaT=self.area(self.totalT,self.tp,false)
}
}
}
}
fn rank(price:float)->float?{
if !do||self.bad||self.totalV<=0.0||self.keys.len !=self.prefix.len{
return null
}
let lo=0
let hi=self.keys.len
for k in 0..13{
if lo<hi{
let au=int(math.floor(float(lo+hi)/2.0))??lo
let center=(float(self.keys[au]??0)+0.5)*self.rowSize
if center<=price{
lo=au+1
}else{
hi=au
}
}
}
return lo==0?0.0:math.max(0.0,math.min(100.0,100.0*(self.prefix[lo-1]??0.0)/self.totalV))
}
}
state g=Qo{rows:map<int,Qj>(fs?4096:1),keys:int[](fr?4096:1),prefix:float[](do?4096:1),dirty:true,totalV:0.0,totalT:0.0,vaV:Qa{lo:null,hi:null},vaT:Qa{lo:null,hi:null},oldVaV:Qa{lo:null,hi:null},oldVaT:Qa{lo:null,hi:null},period:null,last:null,started:false,full:false,bad:false,rowSize:0.0,vp:null,tp:null,maxV:0.0,maxT:0,previous:null,previousV:null,previousT:null,previousFull:false}
state b1:float?=null
state b2:float?=null
state a9:float?=null
state be:float?=null
fn nd(S:time){
let bZ=pfDay.time
if bZ !=null&&(g.last==null||bZ>g.last){
let last=g.last
let count=last==null?800:math.min(800,math.max(1,int(math.ceil(float(time.durationSeconds(time.diff(bZ,last)))/86400.0))??1))
for k in 0..count{
let aR=count-1-k
let aj=pfDay.time[aR]
if aj !=null&&(g.last==null||aj>g.last)&&time.shiftBars(aj,1,tf:1D)<=S{
let p=time.floor(aj,aZ)
if g.period==null||p>=g.period{
ld(p,S)
if !g.started{
g.full=aj==p
g.started=true
g.rowSize=pfTicks==0?math.max(context.tickSize,(pfDay.close[aR]??0.0)*0.002):float(pfTicks)*context.tickSize
}else{
let la=g.last
if la !=null&&time.shiftBars(la,1,tf:1D)!=aj{
g.full=false
}
}
let l=pfDay.low[aR]
let h=pfDay.high[aR]
let v=pfDay.volume[aR]
let lo=int(math.floor((l??0.0)/g.rowSize))??0
let n=(int(math.floor((h??0.0)/g.rowSize))??lo)-lo+1
if l==null||h==null||v==null{
g.full=false
}else if n<1||n>4096{
g.bad=true
}else{
for j in 0..n{
g.add((float(lo+j)+0.5)*g.rowSize,v/float(n),aj)
}
}
}
g.last=aj
}
}
}
}
fn ni(S:time){
if qY{
nd(S)
}
let bZ=qY?null:pfData.time()
if bZ !=null&&(g.last==null||bZ>g.last){
let last=g.last
let count=last==null?250:math.min(250,math.max(1,(int(math.ceil(float(time.durationSeconds(time.diff(bZ,last)))/float(mW)))??250)))
for k in 0..count{
let aR=count-1-k
let aj=pfData.time(barsAgo:aR)
if aj !=null&&(g.last==null||aj>g.last)&&time.shiftBars(aj,1,tf:bp)<=S{
let p=time.floor(aj,aZ)
if g.period==null||p>=g.period{
ld(p,S)
let gg=pfData.binSize(barsAgo:aR)
let summary=pfData.summary(aR)
if summary==null||gg==null{
g.full=false
}else{
if !g.started{
g.full=aj==p
g.started=true
let fm=math.max(context.tickSize,gg)
g.rowSize=pfTicks==0?fm*4.0:float(pfTicks)*context.tickSize
}else{
let la=g.last
if la !=null&&time.shiftBars(la,1,tf:bp)!=aj{
g.full=false
}
}
if gg>g.rowSize*1.000000001||summary.levels>8192||g.rowSize<=0.0{
g.bad=true
}else if !g.bad{
for j in 0..summary.levels{
let level=pfData.level(j,barsAgo:aR)
if level==null{
g.full=false
}else{
g.add(level.price,level.total,aj)
}
}
}
}
}
g.last=aj
}
}
}
let p=time.floor(S,aZ)
if g.period !=null&&p>g.period{
ld(p,S)
}
if fr{
g.refresh()
}
}
fn ne(S:time,bq:time?,bQ:time?,price:float){
let bt=pfView !="Previous"
let previous=pfView !="Current"&&g.previous !=null&&g.previous==time.shiftBars(time.floor(S,aZ),-1,tf:aZ)
let v=bt&&hH&&!g.bad?g.vp:null
let t=bt&&hG&&!g.bad?g.tp:null
let pv=previous&&hH?g.previousV:null
let pt=previous&&hG?g.previousT:null
let reset=ix1&&time.isNewPeriod(S,bq,aZ)
let bE=ix1&&bq !=null&&time.isNewPeriod(bq,bQ,aZ)
al(pfV,pfVColor,true,false,reset,bE||b1==null,b1,v)
al(pfT,ix72,true,false,reset,bE||b2==null,b2,t)
al(pfPV,color.withAlpha(pfVColor,130),true,false,reset,bE||a9==null,a9,pv)
al(pfPT,color.withAlpha(ix72,130),true,false,reset,bE||be==null,be,pt)
b1=v
b2=t
a9=pv
be=pt
if chart.isLast{
let last=g.last
let eF=g.full&&last !=null&&time.shiftBars(last,1,tf:bp)==time.floor(S,bp)
let jV=eF?"":"*"
let kJ=g.previousFull?"":"*"
let jJ=v !=null&&t !=null&&v==t
let kI=pv !=null&&pt !=null&&pv==pt
bM(100,v !=null,v,str.format("{0} {1}{2}",ix67,jJ?"VPOC/TPOC":"VPOC",jV),pfVColor)
bM(101,t !=null&&!jJ,t,str.format("{0} TPOC{1}",ix67,jV),ix72)
bM(102,pv !=null,pv,str.format("Prev {0} {1}{2}",ix67,kI?"VPOC/TPOC":"VPOC",kJ),color.withAlpha(pfVColor,130))
bM(103,pt !=null&&!kI,pt,str.format("Prev {0} TPOC{1}",ix67,kJ),color.withAlpha(ix72,130))
let lP=(bt&&(g.vaV.lo !=null||g.vaT.lo !=null))||(previous&&(g.oldVaV.lo !=null||g.oldVaT.lo !=null))
let kR=ix70 !="Off"&&((bt&&!eF)||(previous&&!g.previousFull))
if(bt&&g.bad)||(!lP&&v==null&&t==null&&pv==null&&pt==null)||kR{
bw.get(204).set(x:8.0,y:price,text:g.bad&&bt?"Profile limit / row too small":(kR&&lP?"Value area*: partial coverage":"Profile: waiting for confirmed data"),color:color.gray,size:10.0,textAlign:"right")
}else{
let _=bw.delete(204)
}
}
}
type Ql{
id:int
kind:int
price:float
birth:time
touched:bool
}
state ef=entities.linePool(max:cj?nvMax+(ix71?0:300):1)
state pfNaked=Ql[](cj?nvMax:1)
state hE=rolling<int>(cj&&!ix71?300:1)
state b6:int=1
plot pfNV=plot.line(title:"Naked VPOC",color:pfVColor,showLabel:!bo)
plot pfNT=plot.line(title:"Naked TPOC",color:ix72,showLabel:!bo)
fn ng(kind:int,price:float,birth:time)->string{
let C=str.format("n{0}",kind==0?"VPOC":"TPOC")
let ab=time.shiftBars(birth,-1,tf:aZ)
let dy=hn?str.format("{0} · {1}",C,kQ(ab,ix67=="Weekly"?"W":ix67=="Monthly"?"M":ix67=="Quarterly"?"Q":ix67=="Yearly"?"Y":ix67=="4H"?"4H":"D")):C
return ix65&&!bo?str.format("{0} {1}",dy,dC(price)):dy
}
fn lc(kind:int,price:float,birth:time){
let bF=pfNaked.len
if bF==pfNaked.capacity{
bF=0
let bH=pfNaked[0]
for i in 1..pfNaked.len{
let G=pfNaked[i]
if G !=null&&bH !=null&&((G.touched&&!bH.touched)||(G.touched==bH.touched&&G.id<bH.id)){
bH=G
bF=i
}
}
if bH !=null&&!bH.touched{
let _=ef.delete(bH.id)
}
}
let G=Ql{id:b6,kind:kind,price:price,birth:birth,touched:false}
b6+=1
if bF==pfNaked.len{
pfNaked.push(G)
}else{
pfNaked[bF]=G
}
ef.get(G.id).set(x1:birth,y1:price,x2:time.shiftBars(birth,1),y2:price,color:kind==0?pfVColor:ix72,width:ix73,style:a4,extend:a5,text:ak?ng(kind,price,birth):"")
}
fn ld(p:time,S:time){
let last=g.last
if cj&&kW&&p==S&&firstLoaded !=null&&p>firstLoaded&&g.period !=null&&p>g.period&&g.full&&!g.bad&&last !=null&&time.shiftBars(last,1,tf:bp)==p{
let v=g.vp
let t=g.tp
if kY&&v !=null{
lc(0,v,p)
}
if kX&&t !=null{
lc(1,t,p)
}
}
if fr&&(g.period==null||g.period !=p){
g.refresh()
}
g.begin(p)
}
fn nf(S:time,o:float,h:float,l:float,c:float,bq:time?,hU:float?){
let hi=fT?math.max(o,c):h
let lo=fT?math.min(o,c):l
let nv:float?=null
let nt:float?=null
for i in 0..pfNaked.len{
let G=pfNaked[i]
if G !=null&&!G.touched{
let b9=ix10&&bq !=null&&hU !=null&&G.birth<bq&&bl(G.price,math.min(hU,o),math.max(hU,o),math.abs(G.price)*fS)
if S>=G.birth&&(bl(G.price,lo,hi,math.abs(G.price)*fS)||b9){
G.touched=true
pfNaked[i]=G
if ix71{
let _=ef.delete(G.id)
}else{
if hE.isFull{
let ab=hE.first()
if ab !=null{
let _=ef.delete(ab)
}
}
hE.push(G.id)
ef.get(G.id).set(x1:G.birth,y1:G.price,x2:S,y2:G.price,color:color.withAlpha(G.kind==0?pfVColor:ix72,110),width:ix73,style:a4,extend:K)
}
}else{
if G.kind==0&&(nv==null||math.abs(G.price-c)<math.abs(nv-c)){
nv=G.price
}
if G.kind==1&&(nt==null||math.abs(G.price-c)<math.abs(nt-c)){
nt=G.price
}
}
}
}
if chart.isLast{
pfNV.plot(dj||(ak&&(!bo||!ix65))?null:nv)
pfNT.plot(dj||(ak&&(!bo||!ix65))?null:nt)
if !kW{
bw.get(204).set(x:8.0,y:c,text:"Profile naked: use an aligned intraday / daily chart",color:color.gray,size:10.0,textAlign:"right")
}
}
}
plot pfVAH=plot.line(title:str.format("{0} Volume VAH",ix67),color:pfVColor,width:ix73,style:a4)
plot pfVAL=plot.line(title:str.format("{0} Volume VAL",ix67),color:pfVColor,width:ix73,style:a4)
fill pfVAFill=fill.between(pfVAH,pfVAL,color:color.withAlpha(pfVColor,aD))
plot pfTAH=plot.line(title:str.format("{0} TPO VAH",ix67),color:ix72,width:ix73,style:a0)
plot pfTAL=plot.line(title:str.format("{0} TPO VAL",ix67),color:ix72,width:ix73,style:a0)
fill pfTAFill=fill.between(pfTAH,pfTAL,color:color.withAlpha(ix72,aD))
plot pfPVAH=plot.line(title:str.format("{0} Previous volume VAH",ix67),color:color.withAlpha(pfVColor,130),width:ix73,style:a4)
plot pfPVAL=plot.line(title:str.format("{0} Previous volume VAL",ix67),color:color.withAlpha(pfVColor,130),width:ix73,style:a4)
fill pfPVAFill=fill.between(pfPVAH,pfPVAL,color:color.withAlpha(pfVColor,aD))
plot pfPTAH=plot.line(title:str.format("{0} Previous TPO VAH",ix67),color:color.withAlpha(ix72,130),width:ix73,style:a0)
plot pfPTAL=plot.line(title:str.format("{0} Previous TPO VAL",ix67),color:color.withAlpha(ix72,130),width:ix73,style:a0)
fill pfPTAFill=fill.between(pfPTAH,pfPTAL,color:color.withAlpha(ix72,aD))
state dp=float[](8)
fn fH(i:int,area:Qa,nI:PlotLine,my:PlotLine,B:color,reset:bool,bQ:bool,nC:Fill){
let hx=dp[i*2]
let ht=dp[i*2+1]
al(nI,B,true,false,reset,bQ||ht==null,ht,area.hi)
al(my,B,true,false,reset,bQ||hx==null,hx,area.lo)
dp[i*2]=area.lo
dp[i*2+1]=area.hi
if pfVaFill&&area.lo !=null&&area.hi !=null&&hx !=null&&ht !=null&&!reset&&!bQ{
nC.fill()
}
}
fn nj(S:time,bq:time?,bQ:time?){
if dp.len==0{
for k in 0..8{
dp.push(null)
}
}
let bR=Qa{lo:null,hi:null}
let bt=pfView !="Previous"&&!g.bad
let previous=pfView !="Current"&&g.previous !=null&&g.previous==time.shiftBars(time.floor(S,aZ),-1,tf:aZ)
let reset=ix1&&time.isNewPeriod(S,bq,aZ)
let bE=ix1&&bq !=null&&time.isNewPeriod(bq,bQ,aZ)
fH(0,bt&&fu?g.vaV:bR,pfVAH,pfVAL,pfVColor,reset,bE,pfVAFill)
fH(1,bt&&ft?g.vaT:bR,pfTAH,pfTAL,ix72,reset,bE,pfTAFill)
fH(2,previous&&fu?g.oldVaV:bR,pfPVAH,pfPVAL,color.withAlpha(pfVColor,130),reset,bE,pfPVAFill)
fH(3,previous&&ft?g.oldVaT:bR,pfPTAH,pfPTAL,color.withAlpha(ix72,130),reset,bE,pfPTAFill)
}
type Qp{
period:time?
last:time?
mean:float
volume:float
m2:float
full:bool
oldPeriod:time?
oldV:float?
oldD:float?
fn add(t:time,price:float?,aS:float?,mf:timeframe){
let p=time.floor(t,mf)
let last=self.last
if self.period==null||self.period !=p{
self.oldPeriod=self.period
self.oldV=self.full&&self.volume>0.0&&last !=null&&time.shiftBars(last,1,tf:4h)==p?self.mean:null
self.oldD=self.oldV !=null?math.sqrt(math.max(0.0,self.m2/self.volume)):null
self.period=p
self.full=t==p
self.mean=0.0
self.volume=0.0
self.m2=0.0
}else if last !=null&&time.shiftBars(last,1,tf:4h)!=t{
self.full=false
}
self.last=t
if price==null||aS==null||aS<0.0{
self.full=false
}else if aS>0.0{
let total=self.volume+aS
let iS=price-self.mean
self.mean+=iS*(aS/total)
self.m2+=aS*iS*(price-self.mean)
self.volume=total
}
}
fn value(p:time,dev:bool)->float?{
if p==self.period&&self.full&&self.volume>0.0{
return dev?math.sqrt(math.max(0.0,self.m2/self.volume)):self.mean
}
return p==self.oldPeriod?(dev?self.oldD:self.oldV):null
}
}
setup eN=Qp{period:null,last:null,mean:0.0,volume:0.0,m2:0.0,full:false,oldPeriod:null,oldV:null,oldD:null}
state hw=eN
state hm=eN
state hq=eN
state hy=eN
state b0:time?=null
fn mj(S:time){
let bZ=higher.time
let previous=b0
if bZ !=null&&(previous==null||bZ>previous){
let count=previous==null?2500:math.min(2500,math.max(1,int(math.ceil(float(time.durationSeconds(time.diff(bZ,previous)))/14400.0))??1))
for i in 0..count{
let aR=count-1-i
let aj=higher.time[aR]
if aj !=null&&(previous==null||aj>previous)&&time.shiftBars(aj,1,tf:4h)<=S{
let o=higher.open[aR]
let h=higher.high[aR]
let l=higher.low[aR]
let c=higher.close[aR]
let price=dt==0?(h+l+c)/3.0:(dt==1?(o+h+l+c)/4.0:(dt==2?(h+l)/2.0:c))
let aS=higher.volume[aR]
if gY{
hw.add(aj,price,aS,1W)
}
if gW{
hm.add(aj,price,aS,1M)
}
if gX{
hq.add(aj,price,aS,3M)
}
if gZ{
hy.add(aj,price,aS,1Y)
}
b0=aj
}
}
}
}
