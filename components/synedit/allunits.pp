{  $Id$  }
{
 /***************************************************************************
                               allunits.pp

                      dummy unit to compile all units 

 /***************************************************************************
}
unit allunits;

{$mode objfpc}{$H+}

interface

uses
  syntextdrawer, syneditkeycmds, synedittypes, syneditstrconst,
  syneditmiscclasses, syneditmiscprocs, syneditsearch, synedittextbuffer,
  synedit, synhighlighterpas, {synedithighlighter,} syncompletion,
  syneditautocomplete, synhighlighterhtml, synhighlightercpp;
	
implementation

end.

{ =============================================================================

  $Log$
  Revision 1.5  2001/03/12 23:42:40  lazarus
  MG: added synhighlighter for cpp and html

  Revision 1.4  2001/02/21 22:55:25  lazarus
  small bugfixes + added TOIOptions

  Revision 1.3  2001/02/01 19:34:50  lazarus
  TScrollbar created and a lot of code added.

  It's cose to working.
  Shane

  Revision 1.2  2001/01/30 22:55:00  lazarus
  MWE:
    + Added $mode objfpc directive

  Revision 1.1  2001/01/28 16:16:11  lazarus
  MWE:
    + Added synedit to the components


}
