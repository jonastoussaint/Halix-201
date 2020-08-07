#!/bin/csh
# -----------------------------------------------------------------
# File name:     HASM 
# Purpose:       Halix assembler.
# Input file(s):  
#                (1) programname.hal -- Halix assembly language program.
#
# Output file: programname.hlx -- Halix executable machine code.
#                (1) programname.hll -- Halix assembler listing file. 
#                (2) programname.hlx -- Halix executable machine code.
# 
# -----------------------------------------------------------------

repeat 3 echo " "
echo "Halix Assembler version 11 / 2012 Jan 23 (c) EL Jones"
repeat 3 echo " "

if ($#argv != 1) then

   repeat 2 echo " "
   echo " -----------------------------------------------------------"
   echo " USAGE ERROR: ONE argument required. "
   echo ""
   echo " CORRECT USAGE:  HASM source.hal "
   echo " "
   echo "    where: "
   echo " "
   echo "        source.hal -- file containing assembly language code."
   echo " "
   echo " -----------------------------------------------------------"
   exit 1
else
   set halF = $1  
   set extOK = `echo $halF | grep -c "\.hal"`
   if (! $extOK) then
      echo "Input file '$1' must have .hal extension."
      exit 2 
   endif
endif

set hasmDIRECTIVES = ".ALLOC .BEGIN .END"

echo "****  HASM EXECUTION STARTING ... "

#goto STARTHERE
#-| ------------------------------------------------------------
#-| Create output files: listing (hll) and executable (hlx).
#-| ------------------------------------------------------------
set hlxF = `echo $halF | sed "s/\.hal/.hlx/"`
#echo "HLX file = $hlxF"
set hllF = `echo $halF | sed "s/\.hal/.hll/"`
#echo "HLL file = $hllF"

set lstPAD = "          "

#-| --------------------------------------------------------- 
#-| Pass #1 - Identify all labels.
#-|       a) DATA labels (variable names)
#-|       b) Code labels (branch targets)
#-| --------------------------------------------------------- 
rm -f data.hll
echo -n "" > data.hll

#-| -------------------------------------------
#-| Determine size of data allocation from .ALLOC directive
#-|      or default of 10.
#-| -------------------------------------------
@ dSIZE = 10
set DMalloc = (`grep '\.ALLOC' $halF `)
if ($#DMalloc >= 2) then
   set dSIZE = $DMalloc[2]
endif


#-| -------------------------------------------
#-| Write the .DATA directives to DD file.
#-|      or default of 10.
#-| -------------------------------------------
rm -f DD
grep '\.DATA' $halF | grep -v "^#" > DD
set fsize = (`wc DD`)
set lines = $fsize[1]
#echo $lines

#echo "DATA DEFINITIONS -- source lines ******************"
#cat DD
#echo "DATA DEFINITIONS -- source lines ******************"

rm -f data.hll
echo -n "" > data.hll

#-| ----------------------------------------------------------------------
#-| Process the .DATA lines with >=2 tokens.
#-| ----------------------------------------------------------------------
set BADdata = 0
set dADDR = 0
set dataName = ()
set dataAddr = ()
set dataValue = ()
set dataINIT = 0000
set PAD = (0 00 000 )
@ L = 1
while ($L <= $lines)

   #echo -n "LINE $L : "
   #head -$L DD | tail -1

   set tLine =  `head -$L DD | tail -1 `
   #echo "tLine: $tLine"
   set tLine = `echo $tLine | awk -F'#' '{print $1}'` 
   #echo "tLine: $tLine"

   set Line = ( $tLine )
   #echo "Line: $Line"

   if ($#Line < 2) then
      set BADdata = 1
      echo "WARNING: Improperly formed .DATA directive: '$Line' "
      goto BADDATASKIPPED
   endif

   if ($Line[1] != "ALLOC") then
      #-| -------------------------------------------
      #-| Extract data name and value (or default).
      #-| WARNING: Wrap name in '#.#' to disambiguate grep search.
      #-| -------------------------------------------
      set DN = "#$Line[1]#"
      set dataName = ( $dataName $DN ) 
      set dataAddr = ($dataAddr $dADDR) 
      set val = 9999
 
      if ($#Line >= 3) then
         set val = `echo $Line[3] | sed 's/=//'`
      endif

      set pad = 0
      if ($val < 1000) set pad = 1
      if ($val < 100) set pad = 2
      if ($val < 10) set pad = 3
      if ($pad > 0) set val = $PAD[$pad]$val
      set dataValue = ($dataValue $val) 

      if ($dADDR < 10) then
         set dADDR = 0$dADDR
      endif
     
      #echo -n "$dADDR  $val  " 
      #head -$L DD | tail -1
      echo -n "$dADDR  $val  " >> data.hll
      #echo -n "$dADDR  $val  "
      #head -$L DD | tail -1 | sed "s/$Line[1]/$DN/"
      head -$L DD | tail -1 | sed "s/#/;;/g" | sed "s/$Line[1]/$DN/" >> data.hll
    
      #echo "dataName: $dataName"
      #echo "dataAddr: $dataAddr"
      #echo "dataValue: $dataValue"

      @ dADDR++
 
   endif

   BADDATASKIPPED:
   @ L++
end

#-| --------------------------------------------------------
#-| Terminate if data declarations were bad.
#-| --------------------------------------------------------
if ($BADdata) then
   echo "FATAL ERROR: One or more improperly formed .DATA directive detected."
   exit 4
endif

#echo "************* DATA DEFINITIONS *********** "
#echo "DATA NAME: $dataName "
#echo "DATA ADDR: $dataAddr"
#echo "DATA VALUE: $dataValue "
#echo "************* DATA DEFINITIONS *********** "

#-| --------------------------------------------------------
#-| Write the data declaration into Halix machine code.
#-| --------------------------------------------------------
rm -f data.hlx 

if ($dSIZE < $#dataName) set dSIZE = $#dataName

echo $dSIZE > data.hlx
set i = 1
while ($i <= $#dataName)
   echo $dataValue[$i] >> data.hlx
   @ i++
end

STARTHERE:

#-| --------------------------------------------------------
#-| Pass 1 - Identify and assign addresses to code labels.
#-| --------------------------------------------------------
set BEGINs = (`grep -n '\.BEGIN' $halF | awk -F: '{print $1}'`)
if ($#BEGINs >= 1) then
   set cBEGIN = $BEGINs[1]
else
   echo "***** FATAL ERROR: No HASM .BEGIN directive found."
   exit 7
endif
@ cBEGIN++

set ENDs = (`grep -n '\.END' $halF | awk -F: '{print $1}'`)
if ($#ENDs >= 1) then
   set cEND = $ENDs[$#ENDs]
else
   echo "***** FATAL ERROR: No HASM .END directive found."
   exit 8
endif
@ cEND-- 

#echo $cBEGIN
#echo $cEND

set iADDR = 0
set labelName = ()
set labelAddr = ()

rm -f label.hll
echo "LABEL ADDRESSES" > label.hll

#-| -----------------------------------------------
#-| SKIP whole line comments -- begin with '#'.
#-| -----------------------------------------------

@ L = $cBEGIN
@ lines = $cEND
while ($L <= $lines)

   #echo -n "LINE $L : "
   #set Line = (`head -$L $halF  | tail -1 | awk -F# '{print $1}'`)
   set Line = (`head -$L $halF  | tail -1 `)

   if ($#Line) then
      if ($Line[1] == "#") then
         goto LINECOMMENTSKIPPED1
      endif
   else
       goto BLANKLINESKIPPED1
   endif  

   if ($iADDR < 10) set iADDR = 0$iADDR
   #echo "$iADDR  $Line"
   
   @ isLabel = 0
   set isLabel = `echo $Line[1] | grep -c ':'`
   if ($isLabel) then
#echo "***** LABEL FOUND: $Line"
      set Label = `echo $Line[1] | awk -F: '{print $1}'`
      set labelName = ($labelName $Label)
      set labelAddr = ($labelAddr $iADDR)
      #echo "LABEL $Label => $iADDR"

#echo "***** LABEL REGISTRY: $iADDR  #$Label#" 
      echo "$iADDR  #$Label#" >> label.hll
      set op = $Line[2]
#echo "Hit ENTER to continue: "
#set go = $<
   else
      set op = $Line[1]
   endif


   @ iADDR++

   LINECOMMENTSKIPPED1: # Comment line skipped.
   BLANKLINESKIPPED1:   # Blank line skipped.

   @ L++
end


repeat 3 echo ""
#echo " =========================================== "

#echo "STOPPING before PASS #2"
#exit

#-| --------------------------------------------------------
#-| Pass 2 - Construct instructions xx yyzz  sourceline 
#-| --------------------------------------------------------
rm -f code.hll docn.hll code.hlx
echo -n "" > docn.hll
echo -n "" > code.hll

echo "-----------------------" >> docn.hll
echo "Halix Assembler Listing" >> docn.hll
echo "   (HASM version 11)" >> docn.hll
echo "-----------------------" >> docn.hll
echo "              " >> docn.hll
echo "Source file: $halF " >> docn.hll
echo "Listing file: $hllF " >> docn.hll
echo "Machine code file: $hlxF " >> docn.hll
echo "              " >> docn.hll

@ codeSIZE = $iADDR
@ iADDR = 0 

@ cBEGIN--
@ cEND++

if ($codeSIZE < 10) set codeSIZE = 0$codeSIZE
echo $codeSIZE > code.hlx

set NULL = "00"
set NOOP = "00"
@ L = $cBEGIN
@ lines = $cEND
while ($L <= $lines)


   #echo -n "LINE $L : "
   set Line = (`head -$L $halF  | tail -1`)
   if ($#Line) then
      if ($Line[1] == "#" || $Line[1] == '.BEGIN' || $Line[1] == '.END' \
          || $Line[1] == '.ALLOC') then
         echo -n "$lstPAD" >> code.hll
         head -$L $halF  | tail -1 | sed "s/#/;;/g" >> code.hll
         goto LINECOMMENTSKIPPED2
      endif
   else
       echo " " >> code.hll
       goto BLANKLINESKIPPED2
   endif

   set Line = (`head -$L $halF  | tail -1 | awk -F'#' '{print $1}'`)
 
   if ($iADDR < 10) set iADDR = 0$iADDR
   #echo -n "$iADDR  " 
   echo -n "$iADDR  " >> code.hll

   set opnd = $NULL
   set op = $NOOP

   set isLabel = `echo $Line | grep -c ':'`
   if ($isLabel) then
      set op = $Line[2]
      if ($#Line >= 3) then
         set opnd = $Line[3]
      endif
   else
      set op = $Line[1]
      if ($#Line >= 2) then
         set opnd = $Line[2]
      endif
   endif

   set isDirective = (`echo $hasmDIRECTIVES | grep -c $op`) 
   set op = "#$op#"
   set OpCode = (`grep $op halix.opcode`)
   if ($#OpCode) then
      set opcode = $OpCode[1]
      #echo OPCODE ... $opcode
   else if ($#isDirective) then
      set opcode = DIRECTIVE
   else
      echo "INVALID OPERATION '$op'" >> code.hll 
      set opcode = $NOOP
      set opnd = $NULL
   endif

   #echo "******"
   #echo $Line
   #echo "OPCODE / OPERAND: $opcode / $opnd "

   #-| --------------------------------------------------------------
   #-| Convert symbolic data/instruction operand to numeric form.
   #-| --------------------------------------------------------------
   switch ($opcode)

     case DIRECTIVE :
                     #-| NO CODE GENERATED/NO ADDRESS.
               
             set instr = '    '
             breaksw
         
     case 00: 
     case 13:
     case 14:
     case 16:
     case 17:
     case 31:
     case 33:
     case 99: 
             #-| ------------------------------------------------------
             #-| These instructions do not require an operand: 00 used.
             #-| ------------------------------------------------------
             set instr = ${opcode}00
             breaksw

     case 10: 
     case 11:
     case 12:
     case 32:
              #-| ---------------------------------------------------------
              #-| Branch instructions require instruction (label) address.
              #-| ---------------------------------------------------------
              set OPN = "#$opnd#"
              set addr = (`grep $OPN label.hll`)
              #echo "LABEL:  $addr"
              if ($#addr) then
                 set iaddr = $addr[1]
                 #echo "$opnd ==> ADDRESS = $iaddr"
              else
                 echo -n "UNDEFINED INSTRUCTION REFERENCE '$opnd' "
                 echo -n "UNDEFINED INSTRUCTION REFERENCE '$opnd' " >> code.hll
                 echo " -- addr 99 used " 
                 echo " -- addr 99 used " >> code.hll 
                 set iaddr = 99
                 #echo "$opnd ==> ADDRESS = $iaddr"
              endif
           
              set instr = $opcode$iaddr
              breaksw

     case 24:
     case 25:
     case 26:
     case 27:
     case 28:
     case 29:
              #-| ----------------------------------------------------------------
              #-| IMMEDIATE value instructions: convert value; store in instruction.
              #-| ----------------------------------------------------------------
              #echo "IMMEDIATE VALUE => $opnd"
              set isValue = (`echo $opnd | grep -c '='`)
              set ival = (`echo $opnd | sed 's/=//'`)
              if (! $isValue) then
                 echo "IMMEDIATE VALUE ERROR - '$opnd'  (missing =) -- value 00 used."
                 echo "IMMEDIATE VALUE ERROR - '$opnd'  (missing =) -- value 00 used." >> code.hll
                 set ival = "00"
              else
                 set notNum = `echo $ival | grep -c "[^0-9]"`
                 if ($notNum) then
                    echo "IMMEDIATE VALUE ERROR - '$opnd'  (NOT NUMERIC) -- value 00 used."
                    echo "IMMEDIATE VALUE ERROR - '$opnd'  (NOT NUMERIC) -- value 00 used." >> code.hll
                    set ival = "00"
                 else
                    if  ($ival < 10) set ival = 0$ival
                 endif
              endif
              set instr = $opcode$ival
              breaksw


              #-| ----------------------------------------------------------------
     default: #-| All remaining instructions require data address.
              #-| ----------------------------------------------------------------
              #echo "SWITCH - $opcode ==> SEARCH $opnd"
     
              set OPND = "#$opnd#" 
              set daddr = (`grep $OPND data.hll`)
              if ($#daddr) then
                 set addr = $daddr[1]
                 #echo "$opnd ==> ADDRESS = $addr"
              else
                 echo "UNDEFINED DATA REFERENCE '$opnd' -- addr 99 used "
                 echo "UNDEFINED DATA REFERENCE '$opnd' -- addr 99 used " >> code.hll 
                 set addr = 99
                 #echo "$opnd ==> ADDRESS = $addr"
              endif
           
              set instr = $opcode$addr
              breaksw

   endsw

   #echo "  $instr  $Line"
   echo -n "$instr  " >> code.hll
   head -$L $halF  | tail -1 | sed "s/#/;;/g" >> code.hll
   echo "$instr  " >> code.hlx

   @ iADDR++

   LINECOMMENTSKIPPED2: # Comment line skipped.
   BLANKLINESKIPPED2:   # Blank line skipped.

   @ L++
end #-while


#-| ----------------------------------------------------------------
#-| Extract and pad documentation lines preceeding DATA section.
#-| ----------------------------------------------------------------

#set cDATA = `grep -n '\.DATA' $halF | awk -F: '{print $1}'`
#@ lines = $cDATA[1]
#@ lines--
#@ L = 1
set cALLOC = (`grep -n '\.ALLOC' $halF | awk -F: '{print $1}'`)
set cDATA = (`grep -n '\.DATA' $halF | awk -F: '{print $1}'`)
set cBEGIN = (`grep -n '\.BEGIN' $halF | awk -F: '{print $1}'`)
if ($#cALLOC) then
  @ stopAT = $cALLOC[1]
else if ($#cDATA) then
  @ stopAT = $cDATA[1]
else
  @ stopAT = $cBEGIN[1]
endif

@ L = 1
while ($L <= $stopAT)
   echo -n "$lstPAD" >> docn.hll
   head -$L $halF  | tail -1 >> docn.hll
   @ L++
end

#-| ----------------------------------------------------------------
#-| Assemble LISTING file from component parts: docn + data + code
#-| ----------------------------------------------------------------

cat data.hlx >> code.hlx

echo " " >> data.hll
echo " " >> docn.hll

cp docn.hll $hllF
sed 's/#//g' data.hll  | sed "s/;;/#/g" >> $hllF
sed 's/#//g' code.hll  | sed "s/;;/#/g" >> $hllF
cp code.hlx $hlxF

#rm code.hll code.hlx docn.hll data.hll 

echo "*********** HASM EXECUTION ENDED NORMALLY *******"
echo " "
echo "See output files: $hllF and $hlxF."
echo " "
echo "==========="
echo "$hllF :"
echo "==========="
more $hllF

echo " "
echo "==========="
echo "$hlxF :"
echo "==========="
more $hlxF


repeat 3 echo " "
echo "Halix Assembler version 11 / 2012 Jan 23 (c) EL Jones"
repeat 3 echo " "

