eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}' && eval 'exec perl -S $0 $argv:q'
        if 0;

#D We started with a hack provided by Thomas Esser. This 
#D expression replaces the unix specific line \type 
#D {#!/usr/bin/perl}.   

#D \module
#D   [       file=texutil.pl,
#D        version=1999.03.14, % 1999.11.05
#D          title=pre- and postprocessing utilities,
#D       subtitle=\TEXUTIL,
#D         author=Hans Hagen,
#D           date=\currentdate,
#D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
#C
#C This module is part of the \CONTEXT\ macro||package and is
#C therefore copyrighted by \PRAGMA. See licen-en.pdf for 
#C details. 

#  Thanks to Tobias    Burnus    for the german translations.
#  Thanks to Thomas    Esser     for hooking it into web2c 
#  Thanks to Taco      Hoekwater for making the file -w proof
#  Thanks to Alex      Knowles   and friends for the right JPG specs
#  Thanks to Sebastian Rahtz     for the eps to PDF method

#  undocumented: 
#
#  --analyze file.pdf       : reports some statistics 
#  --purge   [jobname]      : removes temporary files 

#D This is \TEXUTIL, a utility program (script) to be used
#D alongside the \CONTEXT\ macro package. This \PERL\ script is
#D derived from the \MODULA\ version and uses slightly better
#D algoritms for sanitizing \TEX\ specific (sub|)|strings.
#D
#D This implementation has some features not found in the
#D binary version, like scanning illustrations other than \EPS.
#D I would suggest to keep an eye on the version number:

$Program = "TeXUtil 7.3 - ConTeXt / PRAGMA ADE 1992-2000" ;

#D By the way, this is my first \PERL\ script, which means
#D that it will be improved as soon as I find new and/or more
#D suitable solutions in the \PERL\ manuals. As can be seen in
#D the definition of \type{$Program}, this program is part of
#D the \CONTEXT\ suite, and therefore can communicate with the
#D users in english as well as some other languages. One can
#D set his favourite language by saying something like:

#D \starttypen
#D perl texutil.pl --int=de --fig *.eps *.tif *.pdf *.png *.jpg
#D \stoptypen
#D
#D or simpler:
#D
#D \starttypen
#D perl texutil.pl --fig *.*
#D \stoptypen

#D Of course one can also say \type{--interface=nl}, which
#D happens to be my native language.

#D I won't go into too much detail on the algoritms used.
#D The next few pages show the functionality as reported by the
#D helpinformation and controled by command line arguments
#D and can serve as additional documentation.

#D \TEXUTIL\ can handle different tasks; which one is active
#D depends on the command line arguments. These are handled by
#D a \PERL\ system module. This means that, at least for the
#D moment, there is no external control as provided by the
#D \PRAGMA\ environment system.

use Getopt::Long ;

#D We don't want error messages and accept partial switches,
#D which saves users some typing.

$Getopt::Long::passthrough = 1 ; # no error message
$Getopt::Long::autoabbrev  = 1 ; # partial switch accepted

#D We also predefine the interface language and set a boolean
#D that keeps track of unknown options. \voetnoot {This feature
#D is still to be implemented.}

$UserInterface  = "en" ;
$UnknownOptions = 0 ;
$TcXPath        = '' ; 

#D Here come the options:

&GetOptions
  ("references"     => \$ProcessReferences,
      "ij"                => \$ProcessIJ,
      "high"              => \$ProcessHigh,
      "quotes"            => \$ProcessQuotes,
      "tcxpath=s"         => \$TcXPath, 
   "documents"      => \$ProcessDocuments,
      "type=s"            => \$ProcessType,
      "outputfile=s"      => \$ProcessOutputFile,
      "sources"           => \$ProcessSources,
      "setups"            => \$ProcessSetups,
      "templates"         => \$ProcessTemplates,
      "infos"             => \$ProcessInfos,
   "figures"        => \$ProcessFigures,
      "epspage"          =>\$ProcessEpsPage,
      "epstopdf"         =>\$ProcessEpsToPdf,
   "logfile"        => \$ProcessLogFile,
      "box"               =>\$ProcessBox,
      "hbox"              =>\$ProcessHBox,
      "vbox"              =>\$ProcessVBox,
      "criterium=f"       =>\$ProcessCriterium,
      "unknown"           =>\$ProcessUnknown,
   "purge"          => \$PurgeFiles, 
   "analyze"        => \$AnalyzeFile, 
   "help"           => \$ProcessHelp,
   "silent"         => \$ProcessSilent,
   "verbose"        => \$ProcessVerbose,
   "interface=s"    => \$UserInterface) ;

#D We need some hacks to suppress terminal output. This
#D piece of code is based on page~193 of "Programming Perl".

$ProgramLog = "texutil.log" ;

sub RedirectTerminal
  { open SAVEDSTDOUT, ">&STDOUT" ;
    open STDOUT, ">$ProgramLog" ;
    select STDOUT; $| = 1 }

#D And, indeed:

if ($ProcessSilent)
  { RedirectTerminal }
else
  { $ProcessVerbose = 0 }

#D We can temporary open the terminal channel.

sub OpenTerminal
  { close STDOUT ;
    open STDOUT, ">&SAVEDSTDOUT" }

sub CloseTerminal
  { open SAVEDSTDOUT, ">&STDOUT" ;
    open STDOUT, ">>$ProgramLog" ;
    select STDOUT; $| = 1 }

#D By default wildcards are expanded into a list. The
#D subroutine below is therefore only needed when no file or
#D pattern is given.

$InputFile = "@ARGV" ; # niet waterdicht

#sub CheckInputFiles
# { my ($UserSuppliedPath) = @_ ;
#   @UserSuppliedFiles = map { split " " } sort lc $UserSuppliedPath }

sub CheckInputFiles
 { @UserSuppliedFiles = glob $_[0] }

#D The next subroutine takes care of the optional output
#D filename (e.g. for figure dimensions).

$ProcessOutputFile = "" ;

my $Rubish ; 

sub SetOutputFile
  { ($OutFilNam, $OutFilSuf) = split (/\./, $_[0], 2) ;
    unless ($ProcessOutputFile eq "")
      { $ProcessOutputFile .= "." . $OutFilSuf ;
        ($OutFilNam, $OutFilSuf, $Rubish) = split (/\./, $ProcessOutputFile , 3)}
    $OutputFile = $OutFilNam . "." . $OutFilSuf }

#D Sometimes we need to split filenames.

my ($FileName, $FileSuffix) = ("","") ; 

sub SplitFileName
 { my $Rubish = "" ; 
   if ($_[0] =~ /^\.\//)
     { ($Rubish, $FileName) = split ( /^\.\//, $_[0], 2) }
   else
     { $FileName = $_[0] }
   return split (/\./, $FileName, 2) }

#D In order to support multiple interfaces, we save the
#D messages in a hash table. As a bonus we can get a quick
#D overview of the messages we deal with.

my %MS ; 

sub Report
  { foreach $_ (@_)
      { if (! defined $MS{$_})
          { print $_ }
        else
          { print $MS{$_} }
        print " " }
    print "\n" }

#D The messages are saved in a hash table and are called
#D by name. This contents of this table depends on the
#D interface language in use.

#D \startcompressdefinitions

if ($UserInterface eq "nl")

  { # begin of dutch section

    $MS{"ProcessingReferences"}    = "commando's, lijsten en indexen verwerken" ;
    $MS{"MergingReferences"}       = "indexen samenvoegen" ;
    $MS{"GeneratingDocumentation"} = "ConTeXt documentatie file voorbereiden" ;
    $MS{"GeneratingSources"}       = "ConTeXt broncode file genereren" ;
    $MS{"FilteringDefinitions"}    = "ConTeXt definities filteren" ;
    $MS{"CopyingTemplates"}        = "TeXEdit toets templates copieren" ;
    $MS{"CopyingInformation"}      = "TeXEdit help informatie copieren" ;
    $MS{"GeneratingFigures"}       = "figuur file genereren" ;
    $MS{"FilteringLogFile"}        = "log file filteren (poor mans version)" ;

    $MS{"SortingIJ"}               = "IJ sorteren onder Y" ;
    $MS{"ConvertingHigh"}          = "hoge ASCII waarden converteren" ;
    $MS{"ProcessingQuotes"}        = "characters met accenten afhandelen" ;
    $MS{"ForcingFileType"}         = "filetype instellen" ;
    $MS{"UsingEps"}                = "EPS files afhandelen" ;
    $MS{"UsingTif"}                = "TIF files afhandelen" ;
    $MS{"UsingPdf"}                = "PDF files afhandelen" ;
    $MS{"UsingPng"}                = "PNG files afhandelen" ;
    $MS{"UsingJpg"}                = "JPG files afhandelen" ;
    $MS{"EpsToPdf"}                = "EPS converteren naar PDF";
    $MS{"EpsPage"}                 = "EPS pagina instellen";
    $MS{"FilteringBoxes"}          = "overfull boxes filteren" ;
    $MS{"ApplyingCriterium"}       = "criterium toepassen" ;
    $MS{"FilteringUnknown"}        = "onbekende ... filteren" ;

    $MS{"NoInputFile"}             = "geen invoer file opgegeven" ;
    $MS{"NoOutputFile"}            = "geen uitvoer file gegenereerd" ;
    $MS{"EmptyInputFile"}          = "lege invoer file" ;
    $MS{"NotYetImplemented"}       = "nog niet beschikbaar" ;

    $MS{"Action"}                  = "                 actie :" ;
    $MS{"Option"}                  = "                 optie :" ;
    $MS{"Error"}                   = "                  fout :" ;
    $MS{"Remark"}                  = "             opmerking :" ;
    $MS{"SystemCall"}              = "        systeemaanroep :" ;
    $MS{"BadSystemCall"}           = "  foute systeemaanroep :" ;
    $MS{"MissingSubroutine"}       = "  onbekende subroutine :" ;

    $MS{"EmbeddedFiles"}           = "       gebruikte files :" ;
    $MS{"BeginEndError"}           = "           b/e fout in :" ;
    $MS{"SynonymEntries"}          = "     aantal synoniemen :" ;
    $MS{"SynonymErrors"}           = "                fouten :" ;
    $MS{"RegisterEntries"}         = "       aantal ingangen :" ;
    $MS{"RegisterErrors"}          = "                fouten :" ;
    $MS{"PassedCommands"}          = "     aantal commando's :" ;

    $MS{"MultiPagePdfFile"}        = "      te veel pagina's :" ;
    $MS{"MissingMediaBox"}         = "         geen mediabox :" ;
    $MS{"MissingBoundingBox"}      = "      geen boundingbox :" ;

    $MS{"NOfDocuments"}            = "  documentatie blokken :" ;
    $MS{"NOfDefinitions"}          = "     definitie blokken :" ;
    $MS{"NOfSkips"}                = "  overgeslagen blokken :" ;
    $MS{"NOfSetups"}               = "    gecopieerde setups :" ;
    $MS{"NOfTemplates"}            = " gecopieerde templates :" ;
    $MS{"NOfInfos"}                = " gecopieerde helpinfos :" ;
    $MS{"NOfFigures"}              = "     verwerkte figuren :" ;
    $MS{"NOfBoxes"}                = "        te volle boxen :" ;
    $MS{"NOfUnknown"}              = "         onbekende ... :" ;

    $MS{"InputFile"}               = "           invoer file :" ;
    $MS{"OutputFile"}              = "          outvoer file :" ;
    $MS{"FileType"}                = "             type file :" ;
    $MS{"EpsFile"}                 = "              eps file :" ;
    $MS{"PdfFile"}                 = "              pdf file :" ;
    $MS{"TifFile"}                 = "              tif file :" ;
    $MS{"PngFile"}                 = "              png file :" ;
    $MS{"JpgFile"}                 = "              jpg file :" ;
    $MS{"MPFile"}                  = "         metapost file :" ;

    $MS{"LoadedFilter"}            = "        geladen filter :" ;
    $MS{"RemappedKeys"}            = "     onderschepte keys :" ;
    $MS{"WrongFilterPath"}         = "       fout filter pad :" ;

    $MS{"Overfull"}                = "te vol" ;
    $MS{"Entries"}                 = "ingangen" ;
    $MS{"References"}              = "verwijzingen" ;

  } # end of dutch section

elsif ($UserInterface eq "de")

  { # begin of german section

    $MS{"ProcessingReferences"}    = "Verarbeiten der Befehle, Listen und Register" ;
    $MS{"MergingReferences"}       = "Register verschmelzen" ; 
    $MS{"GeneratingDocumentation"} = "Vorbereiten der ConTeXt-Dokumentationsdatei" ;
    $MS{"GeneratingSources"}       = "Erstellen einer nur Quelltext ConTeXt-Datei" ;
    $MS{"FilteringDefinitions"}    = "Filtern der ConTeXt-Definitionen" ;
    $MS{"CopyingTemplates"}        = "Kopieren der TeXEdit-Test-key-templates" ;
    $MS{"CopyingInformation"}      = "Kopieren der TeXEdit-Hilfsinformation" ;
    $MS{"GeneratingFigures"}       = "Erstellen einer Abb-Uebersichtsdatei" ;
    $MS{"FilteringLogFile"}        = "Filtern der log-Datei" ;

    $MS{"SortingIJ"}               = "Sortiere IJ nach Y" ;
    $MS{"ConvertingHigh"}          = "Konvertiere hohe ASCII-Werte" ;
    $MS{"ProcessingQuotes"}        = "Verarbeiten der Akzentzeichen" ;
    $MS{"ForcingFileType"}         = "Dateityp einstellen" ;
    $MS{"UsingEps"}                = "EPS-Dateien verarbeite" ;
    $MS{"UsingTif"}                = "TIF-Dateien verarbeite" ;
    $MS{"UsingPdf"}                = "PDF-Dateien verarbeite" ;
    $MS{"UsingPng"}                = "PNG-Dateien verarbeite" ;
    $MS{"UsingJpg"}                = "JPG-Dateien verarbeite" ;
    $MS{"EpsToPdf"}                = "convert EPS to PDF";
    $MS{"EpsPage"}                 = "setup EPS page";

    $MS{"FilteringBoxes"}          = "Filtern der ueberfuellten Boxen" ;
    $MS{"ApplyingCriterium"}       = "Anwenden des uebervoll-Kriteriums" ;
    $MS{"FilteringUnknown"}        = "Filter unbekannt ..." ;

    $MS{"NoInputFile"}             = "Keine Eingabedatei angegeben" ;
    $MS{"NoOutputFile"}            = "Keine Ausgabedatei generiert" ;
    $MS{"EmptyInputFile"}          = "Leere Eingabedatei" ;
    $MS{"NotYetImplemented"}       = "Noch nicht verfuegbar" ;

    $MS{"Action"}                  = "                Aktion :" ;
    $MS{"Option"}                  = "                Option :" ;
    $MS{"Error"}                   = "                Fehler :" ;
    $MS{"Remark"}                  = "             Anmerkung :" ;
    $MS{"SystemCall"}              = "           system call :" ;
    $MS{"BadSystemCall"}           = "       bad system call :" ;
    $MS{"MissingSubroutine"}       = "    missing subroutine :" ;
    $MS{"SystemCall"}              = "          Systemaufruf :" ;
    $MS{"BadSystemCall"}           = "   Fehlerhafter Aufruf :" ;
    $MS{"MissingSubroutine"}       = " Fehlende Unterroutine :" ;

    $MS{"EmbeddedFiles"}           = "  Eingebettete Dateien :" ;
    $MS{"BeginEndError"}           = "   Beg./Ende-Fehler in :" ;
    $MS{"SynonymEntries"}          = "      Synonymeintraege :" ;
    $MS{"SynonymErrors"}           = " Fehlerhafte Eintraege :" ;
    $MS{"RegisterEntries"}         = "     Registereintraege :" ;
    $MS{"RegisterErrors"}          = " Fehlerhafte Eintraege :" ;
    $MS{"PassedCommands"}          = "    Verarbeite Befehle :" ;

    $MS{"MultiPagePdfFile"}        = "       zu viele Seiten :" ;
    $MS{"MissingMediaBox"}         = "     fehlende mediabox :" ;
    $MS{"MissingBoundingBox"}      = "  fehlende boundingbox :" ;

    $MS{"NOfDocuments"}            = "       Dokumentbloecke :" ;
    $MS{"NOfDefinitions"}          = "    Definitionsbloecke :" ;
    $MS{"NOfSkips"}                = "Uebersprungene Bloecke :" ;
    $MS{"NOfSetups"}               = "       Kopierte setups :" ;
    $MS{"NOfTemplates"}            = "    Kopierte templates :" ;
    $MS{"NOfInfos"}                = "    Kopierte helpinfos :" ;
    $MS{"NOfFigures"}              = "     Verarbeitete Abb. :" ;
    $MS{"NOfBoxes"}                = "        Zu volle Boxen :" ;
    $MS{"NOfUnknown"}              = "         Unbekannt ... :" ;

    $MS{"InputFile"}               = "          Eingabedatei :" ;
    $MS{"OutputFile"}              = "          Ausgabedatei :" ;
    $MS{"FileType"}                = "              Dateityp :" ;
    $MS{"EpsFile"}                 = "             eps-Datei :" ;
    $MS{"PdfFile"}                 = "             pdf-Datei :" ;
    $MS{"TifFile"}                 = "             tif-Datei :" ;
    $MS{"PngFile"}                 = "             png-Datei :" ;
    $MS{"JpgFile"}                 = "             jpg-Datei :" ;
    $MS{"MPFile"}                  = "        metapost-Datei :" ;

    $MS{"LoadedFilter"}            = "         loaded filter :" ; # tobias
    $MS{"RemappedKeys"}            = "         remapped keys :" ; # tobias
    $MS{"WrongFilterPath"}         = "     wrong filter path :" ; # tobias

    $MS{"Overfull"}                = "zu voll" ;
    $MS{"Entries"}                 = "Eintraege" ;
    $MS{"References"}              = "Referenzen" ;

  } # end of german section

else

  { # begin of english section

    $MS{"ProcessingReferences"}    = "processing commands, lists and registers" ;
    $MS{"MergingReferences"}       = "merging registers" ; 
    $MS{"GeneratingDocumentation"} = "preparing ConTeXt documentation file" ;
    $MS{"GeneratingSources"}       = "generating ConTeXt source only file" ;
    $MS{"FilteringDefinitions"}    = "filtering formal ConTeXt definitions" ;
    $MS{"CopyingTemplates"}        = "copying TeXEdit quick key templates" ;
    $MS{"CopyingInformation"}      = "copying TeXEdit help information" ;
    $MS{"GeneratingFigures"}       = "generating figure directory file" ;
    $MS{"FilteringLogFile"}        = "filtering log file" ;

    $MS{"SortingIJ"}               = "sorting IJ under Y" ;
    $MS{"ConvertingHigh"}          = "converting high ASCII values" ;
    $MS{"ProcessingQuotes"}        = "handling accented characters" ;
    $MS{"ForcingFileType"}         = "setting up filetype" ;
    $MS{"UsingEps"}                = "processing EPS-file" ;
    $MS{"UsingTif"}                = "processing TIF-file" ;
    $MS{"UsingPdf"}                = "processing PDF-file" ;
    $MS{"UsingPng"}                = "processing PNG-file" ;
    $MS{"UsingJpg"}                = "processing JPG-file" ;
    $MS{"EpsToPdf"}                = "convert EPS to PDF";
    $MS{"EpsPage"}                 = "setup EPS page";

    $MS{"FilteringBoxes"}          = "filtering overfull boxes" ;
    $MS{"ApplyingCriterium"}       = "applying overfull criterium" ;
    $MS{"FilteringUnknown"}        = "filtering unknown ..." ;

    $MS{"NoInputFile"}             = "no input file given" ;
    $MS{"NoOutputFile"}            = "no output file generated" ;
    $MS{"EmptyInputFile"}          = "empty input file" ;
    $MS{"NotYetImplemented"}       = "not yet available" ;

    $MS{"Action"}                  = "                action :" ;
    $MS{"Option"}                  = "                option :" ;
    $MS{"Error"}                   = "                 error :" ;
    $MS{"Remark"}                  = "                remark :" ;
    $MS{"SystemCall"}              = "           system call :" ;
    $MS{"BadSystemCall"}           = "       bad system call :" ;
    $MS{"MissingSubroutine"}       = "    missing subroutine :" ;

    $MS{"EmbeddedFiles"}           = "        embedded files :" ;
    $MS{"BeginEndError"}           = "          b/e error in :" ;
    $MS{"SynonymEntries"}          = "       synonym entries :" ;
    $MS{"SynonymErrors"}           = "           bad entries :" ;
    $MS{"RegisterEntries"}         = "      register entries :" ;
    $MS{"RegisterErrors"}          = "           bad entries :" ;
    $MS{"PassedCommands"}          = "       passed commands :" ;

    $MS{"MultiPagePdfFile"}        = "        too many pages :" ;
    $MS{"MissingMediaBox"}         = "      missing mediabox :" ;
    $MS{"MissingBoundingBox"}      = "   missing boundingbox :" ;

    $MS{"NOfDocuments"}            = "       document blocks :" ;
    $MS{"NOfDefinitions"}          = "     definition blocks :" ;
    $MS{"NOfSkips"}                = "        skipped blocks :" ;
    $MS{"NOfSetups"}               = "         copied setups :" ;
    $MS{"NOfTemplates"}            = "      copied templates :" ;
    $MS{"NOfInfos"}                = "      copied helpinfos :" ;
    $MS{"NOfFigures"}              = "     processed figures :" ;
    $MS{"NOfBoxes"}                = "        overfull boxes :" ;
    $MS{"NOfUnknown"}              = "           unknown ... :" ;

    $MS{"InputFile"}               = "            input file :" ;
    $MS{"OutputFile"}              = "           output file :" ;
    $MS{"FileType"}                = "             file type :" ;
    $MS{"EpsFile"}                 = "              eps file :" ;
    $MS{"PdfFile"}                 = "              pdf file :" ;
    $MS{"TifFile"}                 = "              tif file :" ;
    $MS{"PngFile"}                 = "              png file :" ;
    $MS{"JpgFile"}                 = "              jpg file :" ;
    $MS{"MPFile"}                  = "         metapost file :" ;

    $MS{"LoadedFilter"}            = "         loaded filter :" ;
    $MS{"RemappedKeys"}            = "         remapped keys :" ;
    $MS{"WrongFilterPath"}         = "     wrong filter path :" ; 

    $MS{"Overfull"}                = "overfull" ;
    $MS{"Entries"}                 = "entries" ;
    $MS{"References"}              = "references" ;

  } # end of english section

#D \stopcompressdefinitions

#D Showing the banner (name and version of the program) and
#D offering helpinfo is rather straightforward.

sub ShowBanner
  { Report("\n $Program\n") }

sub ShowHelpInfo
  { Report("HelpInfo") }

#D The helpinfo is also saved in the hash table. This looks
#D like a waste of energy and space, but the program gains
#D readability.

#D \startcompressdefinitions

if ($UserInterface eq "nl")

  { # begin of dutch section

    $MS{"HelpInfo"} =

"          --references   hulp file verwerken / tui->tuo                 \n" .
"                       --ij : IJ als Y sorteren                         \n" .
"                       --high : hoge ASCII waarden converteren          \n" .
"                       --quotes : quotes converteren                    \n" .
"                       --tcxpath : tcx filter pad                       \n" .
"                                                                        \n" .
"           --documents   documentatie file genereren / tex->ted         \n" .
"             --sources   broncode file genereren / tex->tes             \n" .
"              --setups   ConTeXt definities filteren / tex->texutil.tus \n" .
"           --templates   TeXEdit templates filteren / tex->tud          \n" .
"               --infos   TeXEdit helpinfo filteren / tex->tud           \n" .
"                                                                        \n" .
"             --figures   eps figuren lijst genereren / *->texutil.tuf   \n" .
"                       --epspage : voorbereiden voor pdf                \n" .
"                       --epstopdf : omzetten naar pdf                   \n" .
"                                                                        \n" .
"             --logfile   logfile filteren / log->$ProgramLog            \n" .
"                       --box : overfull boxes controleren               \n" .
"                       --criterium : overfull criterium in pt           \n" .
"                       --unknown :onbekende ... controleren             \n" ;

  } # end of dutch section

elsif ($UserInterface eq "de")             

  { # begin of german section

    $MS{"HelpInfo"} =

"          --references   Verarbeiten der Hilfsdatei / tui->tuo          \n" .
"                       --ij : Sortiere IJ als Y                         \n" .
"                       --high : Konvertiere hohe ASCII-Werte            \n" .
"                       --quotes : Konvertiere akzentuierte Buchstaben   \n" .
"                       --tcxpath : tcx Filter Path                      \n" .
"                                                                        \n" .
"           --documents   Erstelle Dokumentationsdatei / tex->ted        \n" .
"             --sources   Erstelle reine Quelltextdateien / tex->tes     \n" .
"              --setups   Filtere ConTeXt-Definitionen / tex->texutil.tus\n" .
"           --templates   Filtere TeXEdit-templates / tex->tud           \n" .
"               --infos   Filtere TeXEdit-helpinfo / tex->tud            \n" .
"                                                                        \n" .
"             --figures   Erstelle eps-Abbildungsliste / *->texutil.tuf  \n" .
"                       --epspage : Bereite fuer pdf vor                 \n" .
"                       --epstopdf : Konvertiere zu pdf                  \n" .
"                                                                        \n" .
"             --logfile   Filtere log-Datei / log->$ProgramLog           \n" .
"                       --box : Ueberpruefe uebervolle Boxen             \n" .
"                       --criterium : Uebervoll-Kriterium in pt          \n" .
"                       --unknown : Ueberpruefe auf unbekannte ...       \n" ;

  } # end of german section


else

  { # begin of english section

    $MS{"HelpInfo"} =

"          --references   process auxiliary file / tui->tuo              \n" .
"                       --ij : sort IJ as Y                              \n" .
"                       --high : convert high ASCII values               \n" .
"                       --quotes : convert quotes characters             \n" .
"                       --tcxpath : tcx filter path                      \n" .
"                                                                        \n" .
"           --documents   generate documentation file / tex->ted         \n" .
"             --sources   generate source only file / tex->tes           \n" .
"              --setups   filter ConTeXt definitions / tex->texutil.tus  \n" .
"           --templates   filter TeXEdit templates / tex->tud            \n" .
"               --infos   filter TeXEdit helpinfo / tex->tud             \n" .
"                                                                        \n" .
"             --figures   generate eps figure list / *->texutil.tuf      \n" .
"                       --epspage : prepare for pdf                      \n" .
"                       --epstopdf : convert to pdf                      \n" .
"                                                                        \n" .
"             --logfile   filter logfile / log->$ProgramLog              \n" .
"                       --box : check overful boxes                      \n" .
"                       --criterium : overfull criterium in pt           \n" .
"                       --unknown : check unknown ...                    \n" ;

  } # end of english section

#D \stopcompressdefinitions

#D In order to sort strings correctly, we have to sanitize
#D them. This is especially needed when we include \TEX\
#D commands, quotes characters and compound word placeholders.
#D
#D \startopsomming[opelkaar]
#D \som  \type{\name}: csnames are stripped
#D \som  \type{{}}: are removed
#D \som  \type{\"e}: and alike are translated into \type{"e} etc.
#D \som  \type{"e}: is translated into an \type{e} and \type{b} etc.
#D \som  \type{||}: becomes \type{-}
#D \som  \type{\-}: also becomes \type{-}
#D \stopopsomming
#D
#D Of course other accented characters are handled too. The
#D appended string is responsible for decent sorting.
#D
#D \startPL
#D $TargetString = SanitizedString ( $SourceString ) ;
#D \stopPL
#D
#D The sort order depends on the ordering in array
#D \type{$ASCII}:

$ASCII{"^"} = "a" ;  $ASCII{'"'} = "b" ;  $ASCII{"`"} = "c" ;
$ASCII{"'"} = "d" ;  $ASCII{"~"} = "e" ;  $ASCII{","} = "f" ;

#sub SanitizedString
#  { my ($string) = $_[0] ;
#    if ($ProcessQuotes)
#      { $string =~ s/\\([\^\"\`\'\~\,])/$1/gio ;
#        $copied = $string ;
#        $copied =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$ASCII{$1}/gio ;
#        $string =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$2/gio ;
#        $string=$string.$copied }
#    $string =~ s/\\-|\|\|/\-/gio ;
#    $string =~ s/\\[a-zA-Z]*| |\{|\}//gio ;
#    return $string }

#D YET UNDOCUMENTED

my $SortN = 0 ; my @Filter ; 

# copied from texexec

my @paths ; 
my $kpsewhich = '' ;
my $pathslash = '/' ; if ($0 =~ /\\/) { $pathslash = "\\" }

sub checked_path
  { my $path = shift  ;
    if ((defined($path))&&($path ne ''))
      { $path =~ s/[\/\\]/$pathslash/go ;
        $path =~ s/[\/\\]*$//go ;
        $path .= $pathslash }
    else
      { $path = '' }
    return $path }

if ($ENV{PATH} =~ /\;/)
  { @paths = split(/\;/,$ENV{PATH}) }
else
  { @paths = split(/\:/,$ENV{PATH}) }

# until here.

sub InitializeKeys 
  { my $filename = $ARGV[0] ;
    return unless (open(TEX,"$filename.tex")) ;
    for ($i=0;$i<=255;$i++) 
      { @Filter[$i] = $i } 
    if ($TcXPath eq '') 
      { foreach (@paths) 
          { my $p = checked_path($_) . 'kpsewhich' ;
            if ((-e $p)||(-e $p . '.exe'))
              { $kpsewhich = $p ; last } } } 
    while (<TEX>)
      { chomp ; 
        my $Filter ; 
        if (/^\%/) 
          { if (s/.*translat.*?=([\:\/0-9\-a-z]*)/$1/oi) 
              { my $Translation = $_ ; 
                if ($TcXPath ne '') 
                  { $TcXPath = checked_path($TcXPath) ; 
                    $Filter = "$TcXPath$pathslash$Translation.tcx" }
                elsif ($kpsewhich ne '') 
                  { $Filter = `$kpsewhich --format="web2c files" $Translation.tcx` ;
                    chomp $Filter } 
                else
                  { last } 
                if (open(ASC,$Filter)) 
                  { Report ("LoadedFilter", $Translation) ;
                    while (<ASC>)
                      { if (/^(\d+)\s*(\d+)/) 
                          { @Filter[$2] = $1 } } 
                    close (ASC) } 
                elsif ($TcXPath ne '') 
                  { Report ("WrongFilterPath", $TcXPath) }
                last } } 
        else
          { last } }
    close (TEX) } 

sub HandleKey 
  { ++$SortN ;
    $RestOfLine =~ s/\{(.*)\}/$1/o ;
    my ($lan, $enc, $str, $chr, $map, $alf) = split(/\}\s*\{/, $RestOfLine) ;
    if ($str =~ /^(\d+)/) { $str = ''.chr(@Filter[$1]) } 
    $map = chr(ord($MAP[$i])+128) ; 
    $STR[$SortN] = $str ;
    $CHR[$SortN] = $chr ;
    $MAP[$SortN] = $map ;
    $ALF{"$chr$map"} = $alf }

sub FlushKeys 
  { Report ("RemappedKeys", $SortN) }

sub SanitizedString
  { my $string = shift ; 
    if ($SortN)
      { my $copied = $string ; 
        for ($i=1;$i<=$SortN;$i++)
          { my $s = $STR[$i] ; 
            my $m = $MAP[$i] ;
            my $c = $CHR[$i] ; 
            $string =~ s/($s)/$c/ge ;
            $copied =~ s/($s)/$m/eg }  
       #print "$string $copied\n" ; 
        $string .= "\x00"; 
        $string .= $copied } 
    elsif ($ProcessQuotes) 
      { $string =~ s/\\([\^\"\`\'\~\,])/$1/gio ;
        $copied = $string ;
        $copied =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$ASCII{$1}/gio ;
        $string =~ s/([\^\"\`\'\~\,])([a-zA-Z])/$2/gio ;
        $string .= "\x00"; 
        $string .= $copied } 
    $string =~ s/\\-|\|\|/\-/gio ;
    $string =~ s/\\[a-zA-Z]*| |\{|\}//gio ;
    return $string } 

#D This subroutine looks a bit complicated, which is due to the
#D fact that we want to sort for instance an accented \type{e}
#D after the plain \type{e}, so the imaginary words
#D
#D \starttypen
#D eerste
#D \"eerste
#D \"e\"erste
#D eerst\"e
#D \stoptypen
#D
#D come out in an acceptable order.

#D We also have to deal with the typical \TEX\ sequences with
#D the double \type{^}'s, like \type{^^45}. These hexadecimal
#D coded characters are just converted.
#D
#D \startPL
#D $TargetString = HighConverted ( $SourceString ) ;
#D \stopPL

sub HighConverted
  { my ($string) = $_[0] ;
    $string =~ s/\^\^([a-f0-9][a-f0-9])/chr hex($1)/geo ;
    return $string }

#D \extras
#D   {references}
#D
#D \CONTEXT\ can handle many lists, registers (indexes),
#D tables of whatever and references. This data is collected
#D in one pass and processed in a second one. In between,
#D relevant data is saved in the file \type{\jobname.tui}.
#D This file also holds some additional information concerning
#D second pass optimizations.
#D
#D The main task of \TEXUTIL\ is to sort lists and registers
#D (indexes). The results are stored in again one file called
#D \type{\jobname.tuo}.
#D
#D Just for debugging purposes the nesting of files loaded
#D during the \CONTEXT\ run is stored. Of course this only
#D applies to files that are handled by the \CONTEXT\ file
#D structuring commands (projects, products, components and
#D environments).
#D
#D We have to handle the entries:
#D
#D \starttypen
#D f b {test}
#D f e {test}
#D \stoptypen
#D
#D and only report some status info at the end of the run.

sub InitializeFiles
  { $NOfFiles = 0 ;
    $NOfBadFiles = 0 }

sub HandleFile
 { $RestOfLine =~ s/.*\{(.*)\}/$1/gio ;
   ++$Files{$RestOfLine} }

sub FlushFiles
  { print TUO "%\n" . "% $Program / Files\n" . "%\n" ;
    foreach $File (keys %Files)
      { print TUO "% $File ($Files{$File})\n" }
    print TUO "%\n" ;
    $NOfFiles = keys %Files ;
    Report("EmbeddedFiles", $NOfFiles) ;
    foreach $File (keys %Files)
      { unless (($Files{$File} % 2) eq 0)
          { ++$NOfBadFiles ;
            Report("BeginEndError", $File) } } }

#D Commands don't need a special treatment. They are just
#D copied. Such commands are tagged by a \type{c}, like:
#D
#D \starttypen
#D c \thisisutilityversion{year.month.day}
#D c \twopassentry{class}{key}{value}
#D c \mainreference{prefix}{entry}{pagenumber}{realpage}{tag}
#D c \listentry{category}{tag}{number}{title}{pagenumber}{realpage}
#D c \initializevariable\realnumberofpages{number}
#D \stoptypen
#D
#D For historic reasons we check for the presense of the
#D backslash.

sub InitializeCommands
  { print TUO "%\n" . "% $Program / Commands\n" . "%\n" ;
    $NOfCommands = 0 }

sub HandleCommand
  { ++$NOfCommands ;
    $RestOfLine =~ s/^\\//go ;
    print TUO "\\$RestOfLine\n" }

sub FlushCommands
  { Report ("PassedCommands", $NOfCommands) }

#D Synonyms are a sort of key||value pairs and are used for
#D ordered lists like abbreviations and units.
#D
#D \starttypen
#D s e {class}{sanitized key}{key}{associated data}
#D \stoptypen
#D
#D The sorted lists are saved as (surprise):
#D
#D \starttypen
#D \synonymentry{class}{sanitized key}{key}{associated data}
#D \stoptypen

sub InitializeSynonyms
  { $NOfSynonyms = 0 ;
    $NOfBadSynonyms = 0 }

#M \definieersynoniem [testname] [testnames] [\testmeaning]
#M
#M \stelsynoniemenin [testname] [criterium=alles]

#D Let's first make clear what we can expect. Synonym
#D entries look like:
#D
#D \startbuffer
#D \testname [alpha] {\sl alpha}  {a greek letter a}
#D \testname {alpha}              {another a}
#D \testname [Beta]  {\kap{beta}} {a greek letter b}
#D \testname {beta}               {indeed another b}
#D \testname {gamma}              {something alike g}
#D \testname {delta}              {just a greek d}
#D \stopbuffer
#D
#D \typebuffer
#D
#D This not that spectacular list is to be sorted according
#D to the keys (names). \haalbuffer

sub HandleSynonym
  { ++$NOfSynonyms ;
    ($SecondTag, $RestOfLine) = split(/ /, $RestOfLine, 2) ;
    ($Class, $Key, $Entry, $Meaning) = split(/} \{/, $RestOfLine) ;
    chop $Meaning ;
    $Class = substr $Class, 1 ;
    if ($Entry eq "")
      { ++$NOfBadSynonyms }
    else
      { $SynonymEntry[$NOfSynonyms] =
          join ($JOIN,$Class,$Key,$Entry,$Meaning) } } 

#D Depending on the settings\voetnoot{One can call for
#D all defined entries, call only the used ones, change
#D layout, attach (funny) commands etc.} a list of
#D {\em testnames} looks like:
#D
#D \plaatslijstmettestnames
#D
#D Watch the order in which these entries are sorted.

sub FlushSynonyms
  { print TUO "%\n" . "% $Program / Synonyms\n" . "%\n" ;
    @SynonymEntry = sort { lc($a) cmp lc($b) } @SynonymEntry ;
    $NOfSaneSynonyms = 0 ;
    for ($n=1; $n<=$NOfSynonyms; $n++)
      { # check normally not needed
        if (($n==1)||($SynonymEntry[$n] ne $SynonymEntry[$n-1]))
          { ($Class, $Key, $Entry, $Meaning) =
               split(/$JOIN/, $SynonymEntry[$n]) ;
            ++$NOfSaneSynonyms ;
            print TUO "\\synonymentry{$Class}{$Key}{$Entry}{$Meaning}\n" } }
    Report("SynonymEntries", $NOfSynonyms, "->", $NOfSaneSynonyms, "Entries") ;
    if ($NOfBadSynonyms>0)
      { Report("SynonymErrors", $NOfBadSynonyms) } }

#D Register entries need a bit more care, especially when they
#D are nested. In the near future we will also handle page
#D ranges.
#D
#D \starttypen
#D r e {class}{tag}{sanitized key}{key}{pagenumber}{realpage}
#D r s {class}{tag}{sanitized key}{key}{string}{pagenumber}
#D r r {class}{tag}{sanitized key}{key}{string}{pagenumber}
#D \stoptypen
#D
#D The last one indicates the start of a range. 

#D The first one is the normal entry, the second one concerns
#D {\em see this or that} entries. Keys are sanitized, unless
#D the user supplies a sanitized key. To save a lot of
#D programming, all data concerning an entry is stored in one
#D string. Subentries are specified as:
#D
#D \starttypen
#D first&second&third
#D first+second+third
#D \stoptypen
#D
#D When these characters are needed for typesetting purposes, we
#D can also use the first character to specify the separator:
#D
#D \starttypen
#D &$x^2+y^2=r^2$
#D +this \& that
#D \stoptypen
#D
#D Subentries are first unpacked and next stored in a
#D consistent way, which means that we can use both separators
#D alongside each other. We leave it to the reader to sort
#D out the dirty tricks.

$SPLIT ="%%" ;
$JOIN ="__" ;

sub InitializeRegisters
  { $NOfEntries = 0 ;
    $NOfBadEntries = 0 }

$ProcessType = "" ; 

$RegStat{"f"} = 1 ;
$RegStat{"e"} = 2 ; # end up between from and to 
$RegStat{"t"} = 3 ;
$RegStat{"s"} = 4 ; 

sub HandleRegister
  { ($SecondTag, $RestOfLine) = split(/ /, $RestOfLine, 2) ;
    ++$NOfEntries ;
    if ($SecondTag eq "s")
      { ($Class, $Location, $Key, $Entry, $SeeToo, $Page ) =
           split(/} \{/, $RestOfLine) ;
        chop $Page ;
        $Class = substr $Class, 1 ;
        $RealPage = 0 }
    else
      { ($Class, $Location, $Key, $Entry, $Page, $RealPage ) =
           split(/} \{/, $RestOfLine) ;
        chop $RealPage ;
        $Class = substr $Class, 1 ;
        $SeeToo = "" }
    #
    $_ = $Key ; 
    if (/\:\:/) 
      { ($PageHow,$Key) = split (/\:\:/) }
    else
      { $PageHow = "" } 
    $_ = $Entry ; 
    if (/\:\:/) 
      { ($TextHow,$Entry) = split (/\:\:/) }
    else
      { $TextHow = "" } 
    #
    if ($Key eq "")
      { $Key = SanitizedString($Entry) }
if ($SortMethod ne '') { $ProcessHigh = 0 } 
    if ($ProcessHigh)
      { $Key = HighConverted($Key) }
    $KeyTag = substr $Key, 0, 1 ; 
    if ($KeyTag eq "&")
      { $Key =~ s/^\&//go ;
        $Key =~ s/([^\\])\&/$1$SPLIT/go }
    elsif ($KeyTag eq "+")
      { $Key =~ s/^\+//go ;
        $Key =~ s/([^\\])\+/$1$SPLIT/go }
    else
      { $Key =~ s/([^\\])\&/$1$SPLIT/go ;
        $Key =~ s/([^\\])\+/$1$SPLIT/go }
    $Key .= " " ; # so, "Word" comes for "Word Another Word" 
    $EntryTag = substr $Entry, 0, 1 ;
    if ($EntryTag eq "&")
      { $Entry =~ s/^\&//go ;
        $Entry =~ s/([^\\])\&/$1$SPLIT/go }
    elsif ($EntryTag eq "+")
      { $Entry =~ s/^\+//go ;
        $Entry =~ s/([^\\])\+/$1$SPLIT/go }
    elsif ($KeyTag eq "&")
      { $Entry =~ s/([^\\])\&/$1$SPLIT/go }
    elsif ($KeyTag eq "+")
      { $Entry =~ s/([^\\])\+/$1$SPLIT/go }
    else
      { $Entry =~ s/([^\\])\&/$1$SPLIT/go ;
        $Entry =~ s/([^\\])\+/$1$SPLIT/go }
    $Key =~ s/^([^a-zA-Z])/ $1/go ;
    if ($ProcessIJ)
      { $Key =~ s/ij/yy/go }
    $LCKey = lc $Key ;
    $RegStatus = $RegStat{$SecondTag} ;
    $RealPageNumber= sprintf("%6i",$RealPage) ; 
    $RegisterEntry[$NOfEntries] = 
      join($JOIN,$Class,$LCKey,$Key,$TextHow,$Entry,$RegStatus,
        $RealPageNumber,$Location,$Page,$PageHow,$SeeToo) } 

#M \definieerregister [testentry] [testentries]

#D The previous routine deals with entries like:
#D
#D \startbuffer
#D \testentry {alpha}
#D \testentry {beta}
#D \testentry {gamma}
#D \testentry {gamma}
#D \testentry {delta}
#D \testentry {epsilon}
#D \testentry {alpha+first}
#D \testentry {alpha+second}
#D \testentry {alpha+second}
#D \testentry {alpha+third}
#D \testentry {alpha+second+one}
#D \testentry {alpha+second+one}
#D \testentry {alpha+second+two}
#D \testentry {alpha+second+three}
#D \testentry {gamma+first+one}
#D \testentry {gamma+second}
#D \testentry {gamma+second+one}
#D
#D \testentry {alpha+fourth}
#D \testentry {&alpha&fourth}
#D \testentry {+alpha+fourth}
#D
#D \testentry [alpha+fourth]      {alpha+fourth}
#D \testentry [&alpha&fourth&one] {&alpha&fourth&one}
#D \testentry [+alpha+fourth+two] {&alpha&fourth&two}
#D
#D \testentry {\kap{alpha}+fifth}
#D \testentry {\kap{alpha}+f\'ifth}
#D \testentry {\kap{alpha}+f"ifth}
#D
#D \testentry [&betaformula] {&$a^2+b^2=c^2$}
#D
#D \testentry {zeta \& more}
#D
#D \testentry [pagehowto::key]{texthowto::entry}
#D
#D \stopbuffer
#D
#D \typebuffer
#D
#D \haalbuffer After being sorted, these entries are
#D turned into something \TEX\ using:

$RegisterEntry[0] = ("") ;

sub How 
  { return "$TextHow\:\:" . "$_[0]" } 

sub FlushRegisters
  { print TUO "%\n" . "% $Program / Registers\n" . "%\n" ;
    @RegisterEntry  = sort { lc($a) cmp lc($b) } @RegisterEntry ;
    $NOfSaneEntries = 0 ;
    $NOfSanePages   = 0 ;
    $LastPage       = "" ;
    $LastRealPage   = "" ;
    $AlfaClass      = "" ;
    $Alfa           = "" ;
    $PreviousA      = "" ;
    $PreviousB      = "" ;
    $PreviousC      = "" ;
    $ActualA        = "" ;
    $ActualB        = "" ;
    $ActualC        = "" ;
    for ($n=1 ; $n<=$NOfEntries ; ++$n)
      { ($Class, $LCKey, $Key, $TextHow, $Entry, $RegisterState, 
           $RealPage, $Location, $Page, $PageHow, $SeeToo) = 
             split(/$JOIN/, $RegisterEntry[$n]) ;
        $RealPage =~ s/^\s*//o ; 
        $TestAlfa = lc substr $Key, 0, 1 ;
#
if ($SortN)  
  { $AlfKey = $Key ; 
    $AlfKey =~ s/(.).*\x00(.).*/$1$2/o ;
    if (defined($ALF{$AlfKey})) 
      { $TestAlfa = $ALF{$AlfKey} } } 
#
        if ((lc $TestAlfa ne lc $Alfa) or ($AlfaClass ne $Class))
          { # $Alfa= lc substr $Key, 0, 1 ;
            $Alfa = $TestAlfa ; 
            $AlfaClass = $Class ;
            if ($Alfa ne " ")
              { print TUO "\\registerentry{$Class}{$Alfa}\n" } }
        ($ActualA, $ActualB, $ActualC ) =
           split(/$SPLIT/, $Entry, 3) ;
        unless ($ActualA) { $ActualA = "" } 
        unless ($ActualB) { $ActualB = "" } 
        unless ($ActualC) { $ActualC = "" } 
        if (How($ActualA) eq $PreviousA)
          { $ActualA = "" }
        else
          { $PreviousA = How($ActualA) ;
            $PreviousB = "" ;
            $PreviousC = "" }
        if (How($ActualB) eq $PreviousB)
          { $ActualB = "" }
        else
          { $PreviousB = How($ActualB) ;
            $PreviousC = "" }
        if (How($ActualC) eq $PreviousC)
          { $ActualC = "" }
        else
          { $PreviousC = How($ActualC) }
        $Copied = 0 ;
        if ($ActualA ne "")
          { print TUO "\\registerentrya{$Class}{$ActualA}\n" ;
            $Copied = 1 }
        if ($ActualB ne "")
          { print TUO "\\registerentryb{$Class}{$ActualB}\n" ;
            $Copied = 1 }
        if ($ActualC ne "")
          { print TUO "\\registerentryc{$Class}{$ActualC}\n" ;
            $Copied = 1 }
        if ($Copied)
          { $NOfSaneEntries++ }
        if ($RealPage eq 0)
#          { print TUO "\\registersee{$Class}{$SeeToo}{$Page}\n" ;
{ print TUO "\\registersee{$Class}{$PageHow,$TextHow}{$SeeToo}{$Page}\n" ;
            $LastPage = $Page ;
            $LastRealPage = $RealPage }
        elsif (($Copied) ||
              ! (($LastPage eq $Page) and ($LastRealPage eq $RealPage)))
#          { print TUO "\\registerpage{$Class}{$Location}{$Page}{$RealPage}\n" ;
{ if ($RegisterState eq $RegStat{"f"}) 
    { print TUO "\\registerfrom{$Class}{$PageHow,$TextHow}{$Location}{$Page}{$RealPage}\n" }
  elsif ($RegisterState eq $RegStat{"t"})  
    { print TUO "\\registerto  {$Class}{$PageHow,$TextHow}{$Location}{$Page}{$RealPage}\n" }
  else 
    { print TUO "\\registerpage{$Class}{$PageHow,$TextHow}{$Location}{$Page}{$RealPage}\n" }
            ++$NOfSanePages ;
            $LastPage = $Page ;
            $LastRealPage = $RealPage } }
    Report("RegisterEntries", $NOfEntries, "->", $NOfSaneEntries, "Entries",
                                                 $NOfSanePages,   "References") ;
    if ($NOfBadEntries>0)
      { Report("RegisterErrors", $NOfBadEntries) } }

#D As promised, we show the results:
#D
#D \plaatstestentry

#D For debugging purposes we flush some status information. The
#D faster machines become, the more important this section will
#D be.

sub FlushData
  { print TUO
      "% \n" .
      "% embedded files   : $NOfFiles ($NOfBadFiles errors)\n" .
      "% passed commands  : $NOfCommands\n" .
      "% synonym entries  : $NOfSynonyms ($NOfBadSynonyms errors)\n" .
      "% register entries : $NOfEntries ($NOfBadEntries errors)" }

#D The functionallity described on the previous few pages is
#D called upon in the main routine:

sub NormalHandleReferences
  { if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { unless (open (TUI, "$InputFile.tui"))
          { Report("Error", "EmptyInputFile", $InputFile) }
        else
          { Report("InputFile", "$InputFile.tui" ) ;
            unlink "$InputFile.tmp" ;
            rename "$InputFile.tuo", "$InputFile.tmp" ;
            Report("OutputFile", "$InputFile.tuo" ) ;
            open (TUO, ">$InputFile.tuo") ;
            print TUO "%\n" . "% $Program / Commands\n" . "%\n" ;
            while (<TUI>)
              { $SomeLine = $_ ;
                chomp $SomeLine ;
                ($FirstTag, $RestOfLine) = split ' ', $SomeLine, 2 ;
                if    ($FirstTag eq "c")
                  { HandleCommand }
                elsif ($FirstTag eq "s")
                  { HandleSynonym }
                elsif ($FirstTag eq "r")
                  { HandleRegister }
                elsif ($FirstTag eq "f")
                  { HandleFile }
                elsif ($FirstTag eq "k")
                  { HandleKey }
                elsif ($FirstTag eq "q")
                  { $ValidOutput = 0 ;
                    last } }
            if ($ValidOutput)
             { FlushCommands ; # already done during pass
               FlushKeys ; 
               FlushRegisters ;
               FlushSynonyms ;
               FlushFiles ;
               FlushData ;
               close (TUO) }
            else
             { close (TUO) ;
               unlink "$InputFile.tuo" ;
               rename "$InputFile.tmp", "$InputFile.tuo" ;
               Report ("Remark", "NoOutputFile") } } } }

my $Suffix ; 

sub MergerHandleReferences
  { unlink "texutil.tuo" ;
    Report("OutputFile", "texutil.tuo" ) ;
    open (TUO, ">texutil.tuo") ;
    foreach $InputFile (@ARGV)
      { ($InputFile, $Suffix) = split (/\./, $InputFile, 2) ;
        unless (open (TUI, "$InputFile.tui"))
          { Report("Error", "EmptyInputFile", $InputFile) }
        else
          { Report("InputFile", "$InputFile.tui" ) ;
            while (<TUI>)
              { $SomeLine = $_ ;
                chomp $SomeLine ;
                ($FirstTag, $RestOfLine) = split ' ', $SomeLine, 2 ;
                if ($FirstTag eq "r")
                  { HandleRegister } } } }
    if ($ValidOutput)
      { FlushRegisters ;
        close (TUO) } 
    else
      { close (TUO) ; 
        unlink "texutil.tuo" ;
        Report ("Remark", "NoOutputFile") } }

# sub HandleReferences
#   { Report("Action", "ProcessingReferences") ;
#     if ($ProcessIJ  )
#       { Report("Option", "SortingIJ") }
#     if ($ProcessHigh)
#       { Report("Option", "ConvertingHigh") }
#     if ($ProcessQuotes)
#       { Report("Option", "ProcessingQuotes") }
#     if ($InputFile eq "")
#       { Report("Error", "NoInputFile") }
#     else
#       { unless (open (TUI, "$InputFile.tui"))
#           { Report("Error", "EmptyInputFile", $InputFile) }
#         else
#           { Report("InputFile", "$InputFile.tui" ) ;
#             InitializeCommands ;
#             InitializeRegisters ;
#             InitializeSynonyms ;
#             InitializeFiles ;
#             $ValidOutput = 1 ;
#             unlink "$InputFile.tmp" ;
#             rename "$InputFile.tuo", "$InputFile.tmp" ;
#             Report("OutputFile", "$InputFile.tuo" ) ;
#             open (TUO, ">$InputFile.tuo") ;
#             while (<TUI>)
#               { $SomeLine = $_ ;
#                 chomp $SomeLine ;
#                 ($FirstTag, $RestOfLine) = split ' ', $SomeLine, 2 ;
#                 if    ($FirstTag eq "c")
#                   { HandleCommand }
#                 elsif ($FirstTag eq "s")
#                   { HandleSynonym }
#                 elsif ($FirstTag eq "r")
#                   { HandleRegister }
#                 elsif ($FirstTag eq "f")
#                   { HandleFile }
#                 elsif ($FirstTag eq "q")
#                   { $ValidOutput = 0 ;
#                     last } }
#             if ($ValidOutput)
#              { FlushCommands ; # already done during pass
#                FlushRegisters ;
#                FlushSynonyms ;
#                FlushFiles ;
#                FlushData ;
#                close (TUO) }
#             else
#              { close (TUO) ;
#                unlink "$InputFile.tuo" ;
#                rename "$InputFile.tmp", "$InputFile.tuo" ;
#                Report ("Remark", "NoOutputFile") } } } }

sub HandleReferences
  { $Merging = @ARGV ;
    $Merging = ($Merging>1) ;
    if ($Merging) 
      { Report("Action", "MergingReferences") }
    else
      { Report("Action", "ProcessingReferences") }
    if ($ProcessIJ  )
      { Report("Option", "SortingIJ") }
    if ($ProcessHigh)
      { Report("Option", "ConvertingHigh") }
    if ($ProcessQuotes)
      { Report("Option", "ProcessingQuotes") }
    InitializeKeys ;
    InitializeCommands ;
    InitializeRegisters ;
    InitializeSynonyms ;
    InitializeFiles ;
    $ValidOutput = 1 ;
    if ($Merging) 
      { MergerHandleReferences }
    else 
      { NormalHandleReferences } }

#D \extras
#D   {documents}
#D
#D Documentation can be woven into a source file. The next
#D routine generates a new, \TEX\ ready file with the
#D documentation and source fragments properly tagged. The
#D documentation is included as comment:
#D
#D \starttypen
#D %D ......  some kind of documentation
#D %M ......  macros needed for documenation
#D %S B       begin skipping
#D %S E       end skipping
#D \stoptypen
#D
#D The most important tag is \type{%D}. Both \TEX\ and
#D \METAPOST\ files use \type{%} as a comment chacacter, while
#D \PERL\ uses \type{#}. Therefore \type{#D} is also handled.
#D
#D The generated file gets the suffix \type{ted} and is
#D structured as:
#D
#D \starttypen
#D \startmodule[type=suffix]
#D \startdocumentation
#D \stopdocumentation
#D \startdefinition
#D \stopdefinition
#D \stopmodule
#D \stoptypen
#D
#D Macro definitions specific to the documentation are not
#D surrounded by start||stop commands. The suffix specifaction
#D can be overruled at runtime, but defaults to the file
#D extension. This specification can be used for language
#D depended verbatim typesetting.

sub HandleDocuments
  { Report("Action", "GeneratingDocumentation") ;
    if ($ProcessType ne "")
      { Report("Option", "ForcingFileType", $ProcessType) }
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = SplitFileName ($FullName) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
                        else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.ted") ;
                open (TED, ">$FileName.ted") ;
                $NOfDocuments   = 0 ;
                $NOfDefinitions = 0 ;
                $NOfSkips       = 0 ;
                $SkipLevel      = 0 ;
                $InDocument     = 0 ;
                $InDefinition   = 0 ;
                if ($ProcessType eq "")
                  { $FileType=lc $FileSuffix }
                else
                  { $FileType=lc $ProcessType }
                Report("FileType", $FileType) ;
                print TED "\\startmodule[type=$FileType]\n" ;
                while (<TEX>) 
                  { chomp ;
                    s/\s*$//o ;
                    if (/^[%\#]D/)
                      { if ($SkipLevel == 0)
                          { if (length $_ < 3)  
                              {$SomeLine = "" }
                            else                # HH: added after that
                              {$SomeLine = substr $_, 3 }
                            if ($InDocument)
                              { print TED "$SomeLine\n" }
                            else
                              { if ($InDefinition)
                                  { print TED "\\stopdefinition\n" ;
                                    $InDefinition = 0 }
                                unless ($InDocument)
                                  { print TED "\n\\startdocumentation\n" }
                                print TED "$SomeLine\n" ;
                                $InDocument = 1 ;
                                ++$NOfDocuments } } }
                    elsif (/^[%\#]M/)
                      { if ($SkipLevel == 0)
                          { $SomeLine = substr $_, 3 ;
                            print TED "$SomeLine\n" } }
                   elsif (/^[%\%]S B]/)
                     { ++$SkipLevel ;
                       ++$NOfSkips }
                   elsif (/^[%\%]S E]/)
                     { --$SkipLevel }
                    elsif (/^[%\#]/)
                     { }
                    elsif ($SkipLevel == 0)
                      { $InLocalDocument = $InDocument ;
                        $SomeLine = $_ ;
                        if ($InDocument)
                          { print TED "\\stopdocumentation\n" ;
                            $InDocument = 0 }
                        if (($SomeLine eq "") && ($InDefinition))
                          { print TED "\\stopdefinition\n" ;
                            $InDefinition = 0 }
                        else
                          { if ($InDefinition)
                              { print TED "$SomeLine\n" }
                            elsif ($SomeLine ne "")
                              { print TED "\n" . "\\startdefinition\n" ;
                                $InDefinition = 1 ;
                                unless ($InLocalDocument)
                                  { ++$NOfDefinitions }
                                print TED "$SomeLine\n" } } } }
                if ($InDocument)
                  { print TED "\\stopdocumentation\n" }
                if ($InDefinition)
                  { print TED "\\stopdefinition\n" }
                print TED "\\stopmodule\n" ;
                close (TED) ;
                unless (($NOfDocuments) || ($NOfDefinitions))
                  { unlink "$FileName.ted" }
                Report ("NOfDocuments", $NOfDocuments) ;
                Report ("NOfDefinitions", $NOfDefinitions) ;
                Report ("NOfSkips", $NOfSkips) } } } }

#D \extras
#D   {sources}
#D
#D Documented sources can be stripped of documentation and
#D comments, although at the current processing speeds the
#D overhead of skipping the documentation at run time is
#D neglectable. Only lines beginning with a \type{%} are
#D stripped. The stripped files gets the suffix \type{tes}.

sub HandleSources
  { Report("Action", "GeneratingSources") ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = SplitFileName ($FullName) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.tes") ;
                open (TES, ">$FileName.tes") ;
                $EmptyLineDone = 1 ;
                $FirstCommentDone = 0 ;
                while (<TEX>)
                  { $SomeLine = $_ ;
                    chomp $SomeLine ;
                    if ($SomeLine eq "")
                      { unless ($FirstCommentDone)
                          { $FirstCommentDone = 1 ;
                            print TES
                              "\n% further documentation is removed\n\n" ;
                            $EmptyLineDone = 1 }
                        unless ($EmptyLineDone)
                          { print TES "\n" ;
                            $EmptyLineDone = 1 } }
                    elsif ($SomeLine =~ /^%/)
                      { unless ($FirstCommentDone)
                          { print TES "$SomeLine\n" ;
                            $EmptyLineDone = 0 } }
                    else
                      { print TES "$SomeLine\n" ;
                        $EmptyLineDone = 0 } }
                close (TES) ; 
                unless ($FirstCommentDone)
                  { unlink "$FileName.tes" } } } } }

#D \extras
#D   {setups}
#D
#D All \CONTEXT\ commands are specified in a compact format
#D that can be used to generate quick reference tables and
#D cards. Such setups are preceded by \type{%S}. The setups
#D are collected in the file \type{texutil.tus}.

sub HandleSetups
  { Report("Action", "FilteringDefinitions" ) ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { SetOutputFile ("texutil.tus" ) ;
        Report("OutputFile", $OutputFile) ;
        open (TUS, ">$OutputFile") ; # always reset!
        $NOfSetups = 0 ;
        CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = SplitFileName ($FullName) ;
            unless ($FileSuffix)
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                print TUS "%\n" . "% File : $FileName.$FileSuffix\n" . "%\n" ;
                while (<TEX>)
                  { $SomeLine = $_ ;
                    chomp $SomeLine ;
                    ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) ;
                    if ($Tag eq "%S")
                      { ++$NOfSetups ;
                        while ($Tag eq "%S")
                          { print TUS "$RestOfLine\n" ;
                            $SomeLine = <TEX> ;
                            chomp $SomeLine ;
                            ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                        print TUS "\n" } } } }
        close (TUS) ;
        unless ($NOfSetups)
          { unlink $OutputFile }
        Report("NOfSetups", $NOfSetups) } }

#D \extras
#D   {templates, infos}
#D
#D From the beginning, the \CONTEXT\ source files contained
#D helpinfo and key||templates for \TEXEDIT. In fact, for a
#D long time, this was the only documentation present. More
#D and more typeset (interactive) documentation is replacing
#D this helpinfo, but we still support the traditional method.
#D This information is formatted like:
#D
#D \starttypen
#D %I n=Struts
#D %I c=\strut,\setnostrut,\setstrut,\toonstruts
#D %I
#D %I text
#D %I ....
#D %P
#D %I text
#D %I ....
#D \stoptypen
#D
#D Templates look like:
#D
#D \starttypen
#D %T n=kap
#D %T m=kap
#D %T a=k
#D %T
#D %T \kap{?}
#D \stoptypen
#D
#D The key||value pairs stand for {\em name}, {\em mnemonic},
#D {\em key}. This information is copied to files with the
#D extension \type{tud}.

sub HandleEditorCues
  { if ($ProcessTemplates)
      { Report("Action", "CopyingTemplates" ) }
    if ($ProcessInfos)
      {Report("Action", "CopyingInformation" ) }
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { CheckInputFiles ($InputFile) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = SplitFileName ($FullName) ;
            if ($FileSuffix eq "")
              { $FileSuffix = "tex" }
            unless (-f "$FileName.$FileSuffix")
              { next }
            unless (open (TEX, "$FileName.$FileSuffix"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            else
              { Report("InputFile",  "$FileName.$FileSuffix") ;
                Report("OutputFile", "$FileName.tud") ;
                open (TUD, ">$FileName.tud") ;
                $NOfTemplates = 0 ;
                $NOfInfos = 0 ;
                while (<TEX>)
                  { $SomeLine = $_ ;
                    chomp $SomeLine ;
                    ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) ;
                    if (($Tag eq "%T") && ($ProcessTemplates))
                      { ++$NOfTemplates ;
                       while ($Tag eq "%T")
                         { print TUD "$SomeLine\n" ;
                           $SomeLine = <TEX> ;
                           chomp $SomeLine ;
                           ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                           print TUD "\n" }
                    elsif (($Tag eq "%I") && ($ProcessInfos))
                      { ++$NOfInfos ;
                        while (($Tag eq "%I") || ($Tag eq "%P"))
                          { print TUD "$SomeLine\n" ;
                            $SomeLine = <TEX> ;
                            chomp $SomeLine ;
                            ($Tag, $RestOfLine) = split(/ /, $SomeLine, 2) }
                            print TUD "\n" } }
                close (TUD) ;
                unless (($NOfTemplates) || ($NOfInfos))
                  { unlink "$FileName.tud" }
                if ($ProcessTemplates)
                  { Report("NOfTemplates", $NOfTemplates) }
                if ($ProcessInfos)
                  { Report("NOfInfos", $NOfInfos) } } } } }

#D \extras
#D   {figures}
#D
#D Directories can be scanned for illustrations in \EPS, \PDF,
#D \TIFF, \PNG\ or \JPG\ format. The resulting file \type{texutil.tuf}
#D contains entries like:
#D
#D \starttypen
#D \thisisfigureversion{year.month.day}
#D \presetfigure[file][...specifications...]
#D \stoptypen
#D
#D where the specifications are:
#D
#D \starttypen
#D [e=suffix,x=xoffset,y=yoffset,w=width,h=height,t=title,c=creator,s=size]
#D \stoptypen
#D
#D This data can be used when determining dimensions and
#D generate directories of illustrations.

$DPtoCM = 2.54/72.0 ;
$INtoCM = 2.54 ;

sub SaveFigurePresets
  { my ($FNam, $FTyp, $FUni, $FXof, $FYof, $FWid, $FHei, $FTit, $FCre, $FSiz) = @_ ;
    if ($ProcessVerbose)
      { OpenTerminal ;
        if ($FUni)
          { print "n=$FNam t=$FTyp " .
         (sprintf "x=%1.3fcm y=%1.3fcm ", $FXof, $FYof) .
         (sprintf "w=%1.3fcm h=%1.3fcm\n", $FWid, $FHei) }
        else
          { print "n=$FNam t=$FTyp " .
                  "x=${FXof}bp y=${FYof}bp " .
                  "w=${FWid}bp h=${FHei}bp\n" }
        CloseTerminal }
    else
      { ++$NOfFigures ;
        $Figures[$NOfFigures] = "\\presetfigure[$FNam][e=$FTyp" ;
        if ($FUni)
          { $Figures[$NOfFigures] .= (sprintf ",w=%5.3fcm,h=%5.3fcm", $FWid, $FHei) }
        else
          { $Figures[$NOfFigures] .= ",w=${FWid}bp,h=${FHei}bp" }
        if (($FXof!=0)||($FYof!=0))
          { if ($FUni)
              { $Figures[$NOfFigures] .= (sprintf ",x=%1.3fcm,y=%1.3fcm", $FXof, $FYof) }
            else
              { $Figures[$NOfFigures] .= ",x=${FXof}bp,y=${FYof}bp" } }
        if ($FTit)
          { $Figures[$NOfFigures] .= ",t=\{$FTit\}" }
        if ($FCre)
          { $Figures[$NOfFigures] .= ",c=\{$FCre\}" }
        $Figures[$NOfFigures] .= ",s=$FSiz]\n" } }

#D The \EPS\ to \PDF\ conversion pipe to \GHOSTSCRIPT\ is
#D inspired by a script posted by Sebastian Ratz at the
#D \PDFTEX\ mailing list. Watch the bounding box check, we
#D use the values found in an earlier pass.

sub ConvertEpsToEps
  { my ( $SuppliedFileName , $LLX, $LLY, $URX, $URY ) = @_ ;
    ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
    if ($ProcessEpsToPdf)
      { unlink "$FileName.pdf" ;
        $GSCommandLine = "-q " .
                         "-sDEVICE=pdfwrite " .
                         "-dNOCACHE " .
                         "-dUseFlateCompression=true " .
                         "-sOutputFile=$FileName.pdf " .
                         "- -c " .
                         "quit " ;
        open ( EPS, "| gs $GSCommandLine") }
    elsif ($PDFReady)
      { return }
    else
      { open ( EPS, ">texutil.tmp" ) ;
        binmode EPS }
    open ( TMP , "$SuppliedFileName" ) ;
    binmode TMP ;
    $EpsBBOX = 0 ;
    $EpsWidth   = $URX - $LLX ;
    $EpsHeight  = $URY - $LLY ;
    $EpsXOffset =    0 - $LLX ;
    $EpsYOffset =    0 - $LLY ;
    while (<TMP>)
      { if (/%!PS/)
          { s/(.*)%!PS/%!PS/o ;
            print EPS $_ ;
            last } }
    while (<TMP>)
      { if ((!$PDFReady)&&(/^%%(HiResB|ExactB|B)oundingBox:/o))
          { unless ($EpsBBOX)
              { print EPS "%%PDFready: $Program\n" ;
                print EPS "%%BoundingBox: 0 0 $EpsWidth $EpsHeight\n" ;
                print EPS "<< /PageSize [$EpsWidth $EpsHeight] >> setpagedevice\n" ;
                print EPS "gsave $EpsXOffset $EpsYOffset translate\n" ;
                $EpsBBOX = 1 } }
        elsif (/^%%EOF/o) # when final: (/^%%(EOF|Trailer)/o)  
          { last }
        elsif (/^%%Trailer/o)
          { last }
        else
          { print EPS $_ } }
    close ( TMP ) ;
    if (($EpsBBOX)&&(!$PDFReady))
      { print EPS "grestore\n%%EOF\n%%RestOfFileIgnored: $Program\n" ;
        close ( EPS ) ;
        Report ( "PdfFile", "$SuppliedFileName" ) ;
        unless ($ProcessEpsToPdf)
          { unlink "$SuppliedFileName" ;
            rename "texutil.tmp", "$SuppliedFileName" } }
    else
      { close (EPS) }
    unlink "texutil.tmp" }

sub HandleEpsFigure
  { my ($SuppliedFileName) = @_ ;
    my ($Temp) = "" ; 
    if (-f $SuppliedFileName)
     { ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
       if ($FileSuffix) 
         { $Temp = $FileSuffix ;
           $Temp =~ s/[0-9]//go ;
           if ($Temp eq "")
             { $EpsFileName = $SuppliedFileName;
               Report ( "MPFile", "$SuppliedFileName" ) }
           elsif ((lc $FileSuffix ne "eps")&&(lc $FileSuffix ne "mps"))
             { return }
           else
             { $EpsFileName = $SuppliedFileName; # $FileName
               Report ( "EpsFile", "$SuppliedFileName" ) }
           $EpsTitle = "" ;
           $EpsCreator = "" ;
           open ( EPS , $SuppliedFileName ) ;
           binmode EPS ;
           $EpsSize = -s EPS ;
           $PDFReady = 0 ;
           $MPSFound = 0 ;
           $BBoxFound = 0 ;
           while (<EPS>)
             { $SomeLine = $_;
               chomp $SomeLine ;
               if (($BBoxFound) && ((substr $SomeLine,0,1) ne "%"))
                 { last }
               if ($BBoxFound<2)
                 { if ($SomeLine =~ /^%%BoundingBox:/io)
                     { $EpsBBox = $SomeLine ; $BBoxFound = 1 ; next }
                   elsif ($SomeLine =~ /^%%HiResBoundingBox:/io)
                     { $EpsBBox = $SomeLine ; $BBoxFound = 2 ; next }
                   elsif ($SomeLine =~ /^%%ExactBoundingBox:/io)
                     { $EpsBBox = $SomeLine ; $BBoxFound = 3 ; next } }
               if ($SomeLine =~ /^%%PDFready:/io)
                 { $PDFReady = 1 }
               elsif ($SomeLine =~ /^%%Creator:/io)
                 { ($Tag, $EpsCreator) = split (/ /, $SomeLine, 2) ;
                   if ($EpsCreator =~ /MetaPost/io)
                     { $MPSFound = 1 } }
               elsif ($SomeLine =~ /^%%Title:/io)
                 { ($Tag, $EpsTitle) = split (/ /, $SomeLine, 2) } }
           close ( EPS ) ;
           if ($BBoxFound)
             { ($Tag, $LLX, $LLY, $URX, $URY, $RestOfLine) = split (/ /, $EpsBBox, 6 ) ;
               $EpsHeight  = ($URY-$LLY)*$DPtoCM ;
               $EpsWidth   = ($URX-$LLX)*$DPtoCM ;
               $EpsXOffset = $LLX*$DPtoCM ;
               $EpsYOffset = $LLY*$DPtoCM ;
               if ($MPSFound)
                 { $EpsType = "mps" }
               else
                 { $EpsType = "eps" }
               SaveFigurePresets
                ( $EpsFileName, $EpsType, 1,
                  $EpsXOffset, $EpsYOffset, $EpsWidth, $EpsHeight,
                  $EpsTitle, $EpsCreator, $EpsSize ) ;
               if (($ProcessEpsPage) || ($ProcessEpsToPdf))
                 { ConvertEpsToEps ( $SuppliedFileName, $LLX, $LLY, $URX, $URY ) } }
           else
             { Report ( "MissingBoundingBox", "$SuppliedFileName" ) } } } }
        
#D The \PDF\ scanning does a similar job. This time we
#D search for a mediabox. I could have shared some lines
#D with the previous routines, but prefer readability.

sub HandlePdfFigure
  { my ( $SuppliedFileName ) = @_ ;
    ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
    if (lc $FileSuffix ne "pdf")
      { return }
    else
      { $PdfFileName = $SuppliedFileName ;
        Report ( "PdfFile", "$SuppliedFileName" ) }
    open ( PDF , $SuppliedFileName ) ;
    binmode PDF ;
    $PdfSize = -s PDF ;
    $MediaBoxFound = 0 ;
    $MediaBox = 0 ;
    $PageFound = 0 ;
    $PagesFound = 0 ;
    while (<PDF>)
      { $SomeLine = $_ ;
        chomp ($SomeLine) ;
        if ($SomeLine =~ /\/Type \/Pages/io)
          { $PagesFound = 1 }
        elsif ($SomeLine =~ /\/Type \/Page/io)
          { ++$PageFound ;
            if ($PageFound>1) { last } }
        if ((($PageFound)||($PagesFound)) && ($SomeLine =~ /\/MediaBox /io))
          { $MediaBox = $SomeLine ;
            $MediaBoxFound = 1 ;
            if ($PagesFound) { last } } }
    close ( PDF ) ;
    if ($PageFound>1)
      { Report ( "MultiPagePdfFile", "$SuppliedFileName" ) }
#    elsif (($MediaBoxFound) && ($MediaBox))
    if (($MediaBoxFound) && ($MediaBox))
      { my $D = "[0-9\-\.]" ;
        $MediaBox =~ /\/MediaBox\s*\[\s*($D+)\s*($D+)\s*($D+)\s*($D+)/o ;
        $LLX = $1 ; $LLY = $2 ; $URX = $3 ; $URY = $4 ;
        $PdfHeight = ($URY-$LLY)*$DPtoCM ;
        $PdfWidth = ($URX-$LLX)*$DPtoCM ;
        $PdfXOffset = $LLX*$DPtoCM ;
        $PdfYOffset = $LLY*$DPtoCM ;
        SaveFigurePresets
         ( $PdfFileName, "pdf", 1,
           $PdfXOffset, $PdfYOffset, $PdfWidth, $PdfHeight,
           "", "", $PdfSize ) }
    else
      { Report ( "MissingMediaBox", "$SuppliedFileName" ) } }

#D A previous version of \TEXUTIL\ used \type{tifftags} or
#D \type{tiffinfo} for collecting the dimensions. However,
#D the current implementation does this job itself.

sub TifGetByte
  { my ($B) = 0 ;
    read TIF, $B, 1 ;
    return ord($B) }

sub TifGetShort
  { my ($S) = 0 ;
    read TIF, $S, 2 ;
    if ($TifLittleEndian)
      { return (unpack ("v", $S)) }
    else
      { return (unpack ("n", $S)) } }

sub TifGetLong
  { my ($L) = 0 ;
    read TIF, $L, 4 ;
    if ($TifLittleEndian)
      { return (unpack ("V", $L)) }
    else
      { return (unpack ("N", $L)) } }

sub TifGetRational
  { my ($N, $M) = (0,0) ;
    $N = TifGetLong ;
    $M = TifGetLong ;
    return $N/$M }

sub TifGetAscii
  { my ($S) = "" ;
    --$TifValues;
    if ($TifValues)
      { return "" }
    else
      { read TIF, $S, $TifValues ;
        return $S } }

sub TifGetWhatever
  { if ($_[0]==1)
      { return TifGetByte }
    elsif ($_[0]==2)
      { return TifGetAscii }
    elsif ($_[0]==3)
      { return TifGetShort }
    elsif ($_[0]==4)
      { return TifGetLong }
    elsif ($_[0]==5)
      { return TifGetRational }
    else
      { return 0 } }

sub TifGetChunk
  { seek TIF, $TifNextChunk, 0 ;
    $Length = TifGetShort ;
    $TifNextChunk += 2 ;
    for ($i=1; $i<=$Length; $i++)
      { seek TIF, $TifNextChunk, 0 ;
        $TifTag = TifGetShort ;
        $TifType = TifGetShort ;
        $TifValues = TifGetLong ;
        if ($TifTag==256)
          { $TifWidth = TifGetWhatever($TifType) }
        elsif ($TifTag==257)
          { $TifHeight = TifGetWhatever($TifType) }
        elsif ($TifTag==296)
          { $TifUnit = TifGetWhatever($TifType) }
        elsif ($TifTag==282)
          { seek TIF, TifGetLong, 0 ;
            $TifHRes = TifGetWhatever($TifType) }
        elsif ($TifTag==283)
          { seek TIF, TifGetLong, 0 ;
            $TifVRes = TifGetWhatever($TifType) }
        elsif ($TifTag==350)
          { seek TIF, TifGetLong, 0 ;
            $TifCreator = TifGetWhatever($TifType) }
        elsif ($TifTag==315)
          { seek TIF, TifGetLong, 0 ;
            $TifAuthor = TifGetWhatever($TifType) }
        elsif ($TifTag==269)
          { seek TIF, TifGetLong, 0 ;
            $TifTitle = TifGetWhatever($TifType) }
        $TifNextChunk += 12 }
    seek TIF, $TifNextChunk, 0 ;
    $TifNextChunk = TifGetLong ;
    return ($TifNextChunk>0) }

sub HandleTifFigure
  { my ( $SuppliedFileName ) = @_ ;
    ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
    if (lc $FileSuffix ne "tif")
      { return }
    else
      { $TifFile = $SuppliedFileName ;
        if (open ( TIF, $TifFile )) 
           { Report ( "TifFile", "$SuppliedFileName" ) ;
             binmode TIF;
             $TifWidth = 0 ;
             $TifHeight = 0 ;
             $TifTitle = "" ;
             $TifAuthor = "" ;
             $TifCreator = "" ;
             $TifUnit = 0 ;
             $TifHRes = 1 ;
             $TifVRes = 1 ;
             $TifSize = -s TIF ;
             $TifByteOrder = "" ;  
             seek TIF, 0, 0 ;
             read TIF, $TifByteOrder, 2 ;
             $TifLittleEndian = ($TifByteOrder eq "II") ;
             $TifTag = TifGetShort;
             unless ($TifTag == 42)
               { close ( TIF ) ;
                 return }
             $TifNextChunk = TifGetLong ;
             while (TifGetChunk) { }
             if ($TifUnit==2)
               { $TifMult = $INtoCM }
             else
               { $TifMult = 1 }
                 $TifWidth  = ($TifWidth /$TifHRes)*$TifMult ;
                 $TifHeight = ($TifHeight/$TifVRes)*$TifMult ;
                 close ( TIF ) ;
                 SaveFigurePresets
                  ( $TifFile, "tif", $TifUnit,
                    0, 0, $TifWidth, $TifHeight,
                    $TifTitle, $TifCreator, $TifSize ) } } }

#D I first intended to use the public utility \type{pngmeta}
#D (many thanks to Taco for compiling it), but using this
#D utility to analyze lots of \PNG\ files, I tried to do a
#D similar job in \PERL. Here are the results:

my ($PngSize, $PngWidth, $PngHeight) = (0,0,0) ;
my ($PngMult, $PngHRes, $PngVRes, $PngUnit) = (0,1,1,0) ;
my ($PngFile, $PngTitle, $PngAuthor, $PngCreator) = ("","","") ;
my ($PngNextChunk, $PngLength, $PngType) = (0,0,0) ;
my ($PngKeyword, $PngDummy) = ("","") ;

my $PngSignature = chr(137) . chr(80) . chr(78) . chr(71) .
                   chr (13) . chr(10) . chr(26) . chr(10) ;
sub PngGetByte
  { my ($B) = 0 ;
    read PNG, $B, 1 ;
    return (ord($B)) }

sub PngGetLong
  { my ($L) = 0 ;
    read PNG, $L, 4 ;
    return (unpack("N", $L)) }

sub PngGetChunk
  { if ($PngNextChunk<$PngSize) 
      { seek PNG, $PngNextChunk, 0 ;
        $PngLength = PngGetLong ;
        $PngNextChunk = $PngNextChunk + $PngLength + 12 ;
        read PNG, $PngType, 4 ;
        if ($PngType eq "")
          { return 0 }
        elsif ($PngType eq "IEND")
          { return 0 } 
        elsif ($PngType eq "IHDR")
          { $PngWidth = PngGetLong ;
            $PngHeight = PngGetLong }
        elsif ($PngType eq "pHYs")
          { $PngHRes = PngGetLong ;
            $PngVRes = PngGetLong ;
            read PNG, $PngUnit, 1 }
        elsif ($PngType eq "tEXt")
          { read PNG, $PngKeyword, 79 ;
            read PNG, $PngDummy, 1 ;
            if ( $PngKeyword eq "Title")
              { read PNG, $PngTitle, $Length }
            elsif ( $PngKeyword eq "Author")
              { read PNG, $PngAuthor, $PngLength }
            elsif ( $PngKeyword eq "Software")
              { read PNG, $PngCreator, $PngLength } }
        return 1 } 
    else
      { return 0 } }

sub HandlePngFigure
  { my ( $SuppliedFileName ) = @_ ;
    ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
    if (lc $FileSuffix ne "png")
      { return }
    else
      { $PngFile = $SuppliedFileName ;
        if (open ( PNG, $PngFile ))
          { Report ( "PngFile", "$SuppliedFileName" ) }
            $PngSize = 0  ;
            $PngWidth = 0  ;
            $PngHeight = 0  ;
            $PngTitle = "" ;
            $PngAuthor = "" ;
            $PngCreator = "" ;
            $PngUnit = 0 ;
            $PngVRes = 1 ;
            $PngHRes = 1 ;
            $PngSig = "" ; 
            $PngSize = -s PNG ;
            binmode PNG ;
            seek PNG, 0, 0 ;
            read PNG, $PngSig, 8;
            unless ($PngSig eq $PngSignature)
              { close ( PNG ) ;
                return }
            $PngNextChunk = 8 ;
            while (PngGetChunk) { }
            $PngWidth  = ($PngWidth /$PngVRes) ;
            $PngHeight = ($PngHeight/$PngHRes) ;
            close ( PNG ) ;
            SaveFigurePresets
             ( $PngFile, "png", $PngUnit,
               0, 0, $PngWidth, $PngHeight,
               $PngTitle, $PngCreator, $PngSize ) } }

#D Well, we also offer \JPG\ scanning (actually \JFIF)
#D scanning. (I can recomend David Salomon's book on Data
#D Compression to those interested in the internals of
#D \JPG.)
#D
#D It took me some time to discover that the (sort of)
#D reference document I used had a faulty byte position table.
#D Nevertheless, when I was finaly able to grab the header,
#D Piet van Oostrum pointer me to the \PERL\ script of Alex
#D Knowles (and numerous other contributers), from which I
#D could deduce what segment contained the dimensions.

my ($JpgSize, $JpgWidth, $JpgHeight) = (0,0,0) ;
my ($JpgMult, $JpgUnit, $JpgHRes, $JpgVRes) = (1,0,1,1) ;
my ($JpgFile, $JpgVersion, $JpgDummy) = ("",0,"") ;
my ($JpgSig, $JpgPos, $JpgLen, $JpgSoi, $JpgApp) = ("",0,0,0,0) ;

my $JpgSignature = "JFIF" . chr(0) ;

sub JpgGetByte
  { my ($B) = 0 ;
    read JPG, $B, 1 ;
    return ( ord($B) ) }

sub JpgGetInteger
  { my ($I) = 0 ;
    read JPG, $I, 2 ;
    return (unpack("n", $I)) }

sub HandleJpgFigure
  { my ($SuppliedFileName) = @_ ;
    ($FileName, $FileSuffix) = SplitFileName ($SuppliedFileName) ;
    if (lc $FileSuffix ne "jpg")
     { return }
    else
     { $JpgFile = $SuppliedFileName ;
       Report ( "JpgFile", "$SuppliedFileName" ) }
    open ( JPG, $JpgFile ) ;
    binmode JPG ;
    $JpgSignature = "JFIF" . chr(0) ;
    $JpgSize = -s JPG ;
    $JpgWidth = 0 ;
    $JpgHeight = 0 ;
    $JpgUnit = 0 ;
    $JpgVRes = 1 ;
    $JpgHRes = 1 ;
    seek JPG, 0, 0 ;
    read JPG, $JpgSig, 4 ;
    unless ($JpgSig eq chr(255).chr(216).chr(255).chr(224))
      { close ( JPG ) ;
        return }
    $JpgLen = JpgGetInteger;
    read JPG, $JpgSig, 5 ;
    unless ($JpgSig eq $JpgSignature)
      { close ( JPG ) ;
        return }
    $JpgUnit = JpgGetByte ;
    $JpgVersion = JpgGetInteger ;
    $JpgHRes = JpgGetInteger ;
    $JpgVRes = JpgGetInteger ;
    $JpgPos = $JpgLen + 4 ;
    $JpgSoi = 255 ;
    while ()
     { seek JPG, $JpgPos, 0 ;
       $JpgSoi = JpgGetByte ;
       $JpgApp = JpgGetByte ;
       $JpgLen = JpgGetInteger ;
       if ($JpgSoi!=255)
         { last }
       if (($JpgApp>=192) && ($JpgApp<=195))  # Found in the perl script.
         { $JpgDummy = JpgGetByte ;           # Found in the perl script.
           $JpgHeight = JpgGetInteger ;       # Found in the perl script.
           $JpgWidth = JpgGetInteger }        # Found in the perl script.
       $JpgPos = $JpgPos + $JpgLen + 2 }
    close ( JPG ) ;
    if ($JpgUnit==1)
      { $JpgMult = $INtoCM }
    else
      { $JpgMult = 1 }
    $JpgWidth = ($JpgWidth/$JpgHRes)*$JpgMult ;
    $JpgHeight = ($JpgHeight/$JpgVRes)*$JpgMult ;
    close ( JPG ) ;
    SaveFigurePresets
     ( $JpgFile, "jpg", $JpgUnit,
       0, 0, $JpgWidth, $JpgHeight,
       "", "", $JpgSize ) }

#D Now we can handle figures!

sub InitializeFigures
  { $NOfFigures = 0 }

sub FlushFigures
  { $Figures = sort { lc ($a) cmp lc ($b) } $Figures ;
    SetOutputFile ("texutil.tuf") ;
    open ( TUF, ">$OutputFile" ) ;
    print TUF "%\n" . "% $Program / Figures\n" . "%\n" ;
    print TUF "\\thisisfigureversion\{1996.06.01\}\n" . "%\n" ;
    for ($n=1 ; $n<=$NOfFigures ; ++$n)
      { print TUF $Figures[$n] }
    close (TUF) ;
    if ($NOfFigures)
     { Report("OutputFile", $OutputFile ) }
    else
     { unlink $OutputFile }
    Report ( "NOfFigures", $NOfFigures ) }

sub DoHandleFigures
  { my ($FigureSuffix, $FigureMethod) = @_ ;
    if ($InputFile eq "")
      { $InputFile = $FigureSuffix }
    CheckInputFiles ($InputFile) ;
    foreach $FileName (@UserSuppliedFiles)
      { &{$FigureMethod} ( $FileName ) } }

sub HandleFigures
  { Report("Action",  "GeneratingFigures" ) ;
    foreach $FileType (@ARGV)
     { if ($FileType=~/\.eps/io)
         { Report("Option", "UsingEps") ;
           if ($ProcessEpsToPdf) { Report("Option", "EpsToPdf") }
           if ($ProcessEpsPage) { Report("Option", "EpsPage") }
           last } }
    foreach $FileType (@ARGV)
     { if ($FileType=~/\.pdf/io)
         { Report("Option", "UsingPdf") ;
           last } }
    foreach $FileType (@ARGV)
     { if ($FileType=~/\.tif/io)
         { Report("Option", "UsingTif") ;
          #RunTifPrograms ;
           last } }
    foreach $FileType (@ARGV)
     { if ($FileType=~/\.png/io)
         { Report("Option", "UsingPng") ;
           last } }
    foreach $FileType (@ARGV)
     { if ($FileType=~/\.jpg/io)
         { Report("Option", "UsingJpg") ;
           last } }
    InitializeFigures ;
    DoHandleFigures ("eps", "HandleEpsFigure") ;
    DoHandleFigures ("pdf", "HandlePdfFigure") ;
    DoHandleFigures ("tif", "HandleTifFigure") ;
    DoHandleFigures ("png", "HandlePngFigure") ;
    DoHandleFigures ("jpg", "HandleJpgFigure") ;
    FlushFigures }

#D \extras
#D   {logfiles}
#D
#D This (poor man's) log file scanning routine filters
#D overfull box messages from a log file (\type{\hbox},
#D \type{\vbox} or both). The collected problems are saved
#D in \type{$ProgramLog}. One can specify a selection
#D criterium.
#D
#D \CONTEXT\ reports unknown entities. These can also be
#D filtered. When using fast computers, or when processing
#D files in batch, one has to rely on the log files and/or
#D this filter.

$Unknown = "onbekende verwijzing|" . 
           "unbekannte Referenz|"  .
           "unknown reference|"    .
           "dubbele verwijzing|"   .  
           "duplicate reference|"  .
           "doppelte Referenz"     ;

sub FlushLogTopic
  { unless ($TopicFound)
     { $TopicFound = 1 ;
       print ALL "\n% File: $FileName.log\n\n" } }

sub HandleLogFile
  { if ($ProcessBox)
      { Report("Option", "FilteringBoxes", "(\\vbox & \\hbox)") ;
        $Key = "[h|v]box" }
    elsif ($ProcessHBox)
      { Report("Option", "FilteringBoxes", "(\\hbox)") ;
        $Key = "hbox" ;
        $ProcessBox = 1 }
    elsif ($ProcessVBox)
      { Report("Option", "FilteringBoxes", "(\\vbox)") ;
        $Key = "vbox" ;
        $ProcessBox = 1 }
    if (($ProcessBox) && ($ProcessCriterium))
      { Report("Option", "ApplyingCriterium") }
    if ($ProcessUnknown)
      { Report("Option", "FilteringUnknown") }
    unless (($ProcessBox) || ($ProcessUnknown))
      { ShowHelpInfo ;
        return }
    Report("Action",  "FilteringLogFile" ) ;
    if ($InputFile eq "")
      { Report("Error", "NoInputFile") }
    else
      { $NOfBoxes = 0 ;
        $NOfMatching = 0 ;
        $NOfUnknown = 0 ;
        SetOutputFile ($ProgramLog) ;
        Report("OutputFile", $OutputFile) ;
        CheckInputFiles ($InputFile) ;
        open ( ALL, ">$OutputFile" ) ;
        foreach $FullName (@UserSuppliedFiles)
          { ($FileName, $FileSuffix) = SplitFileName ($FullName) ;
            if (! open (LOG, "$FileName.log"))
              { Report("Error", "EmptyInputFile", "$FileName.$FileSuffix" ) }
            elsif (-e "$FileName.tex")
              { $TopicFound = 0 ;
                Report("InputFile", "$FileName.log") ;
                while (<LOG>)
                  { $SomeLine = $_ ;
                    chomp $SomeLine ;
                    if (($ProcessBox) && ($SomeLine =~ /Overfull \\$Key/))
                      { ++$NOfBoxes ;
                        $SomePoints = $SomeLine ;
                        $SomePoints =~ s/.*\((.*)pt.*/$1/ ;
                        if ($SomePoints>=$ProcessCriterium)
                          { ++$NOfMatching ;
                            FlushLogTopic ;
                            print ALL "$SomeLine\n" ;
                            $SomeLine=<LOG> ;
                            print ALL $SomeLine } }
                    if (($ProcessUnknown) && ($SomeLine =~ /$Unknown/io))
                     { ++$NOfUnknown ;
                       FlushLogTopic ;
                       print ALL "$SomeLine\n" } } } }
        close (ALL) ;
        unless (($NOfBoxes) ||($NOfUnknown))
          { unlink $OutputFile }
        if ($ProcessBox)
          { Report ( "NOfBoxes" , "$NOfBoxes", "->", $NOfMatching, "Overfull") }
        if ($ProcessUnknown)
          { Report ( "NOfUnknown", "$NOfUnknown") } } }

#D Undocumented feature. 

my $removedfiles    = 0 ; 
my $keptfiles       = 0 ; 
my $persistentfiles = 0 ; 
my $reclaimedbytes  = 0 ; 

sub RemoveContextFile
  { my $filename = shift ; 
    my $filesize = -s $filename ;  
    unlink $filename ; 
    if (-e $filename) 
      { ++$persistentfiles ; 
        print "            persistent : $filename\n" } 
    else
      { ++$removedfiles ; $reclaimedbytes += $filesize ;
        print "               removed : $filename\n" } }

sub KeepContextFile
  { my $filename = shift ; 
    ++$keptfiles ; 
    print "                  kept : $filename\n" } 

my   @dontaskprefixes = sort glob "mpx-*" ; 
push @dontaskprefixes , ("tex-form.tex","tex-edit.tex","tex-temp.tex",
                         "texexec.tex","cont-opt.tex","cont-opt.bak") ; 
my   @dontasksuffixes = ("mprun.mp","mpgraph.mp") ;
my   @forsuresuffixes = ("tui","tup","ted","tes","top","log","tmp") ;
my   @texonlysuffixes = ("dvi","ps","pdf") ;
my   @texnonesuffixes = ("tuo","tub") ;

sub PurgeFiles 
  { my $pattern = $ARGV[0] ; 
    if ($pattern eq '') 
      { $pattern  = "*.*" } 
    else
      { $pattern .= "-.*" } 
    my @files = sort glob $pattern ;
    foreach my $file (@dontaskprefixes) 
      { if (-e $file) 
          { RemoveContextFile($file) } } 
    foreach my $suffix (@dontasksuffixes) 
      { foreach (@files) 
          { if (/$suffix$/i)
              { RemoveContextFile($_) } } } 
    foreach my $suffix (@forsuresuffixes)
      { foreach (@files) 
          { if (/\.$suffix$/i)
              { RemoveContextFile($_) } } } 
    foreach (@files) 
      { if (/\.\d*$/)
          { RemoveContextFile($_) } } 
#   foreach my $suffix (@texonlysuffixes)
#     { foreach (@files) 
#         { if (/(.*)\.$suffix$/i)
#             { if (-e "$1.tex") 
#                 { RemoveContextFile($_) } 
#               else
#                 { KeepContextFile($_) } } } } 
    foreach my $suffix (@texnonesuffixes)  
      { foreach (@files) 
          { if (/(.*)\.$suffix$/i)
              { if (!-e "$1.tex") 
                  { RemoveContextFile($_) } 
                else
                  { KeepContextFile($_) } } } } 
    if ($removedfiles||$keptfiles||$persistentfiles)
      { print "\n" } 
    print "         removed files : $removedfiles\n" ;
    print "            kept files : $keptfiles\n" ;
    print "      persistent files : $persistentfiles\n" ;
    print "       reclaimed bytes : $reclaimedbytes\n" }

#D Another undocumented feature. 

sub AnalyzeFile
  { my $filename = $ARGV[0] ;
    return unless (($filename =~ /\.pdf/)&&(-e $filename)) ;
    my $filesize = -s $filename ; 
    print "        analyzing file : $filename\n" ;  
    print "             file size : $filesize\n" ;  
    open (PDF, $filename) ; 
    binmode PDF ; 
    my $Object = 0 ; 
    my $Annot = 0 ; 
    my $Link = 0 ; 
    my $Widget = 0 ; 
    my $Named = 0 ; 
    my $Script = 0 ;
    while (<PDF>)   
      { while (/\d+\s+\d+\s+obj/go)      { ++$Object } ; 
        while (/\/Type\s*\/Annot/go)     { ++$Annot  } ; 
        while (/\/Subtype\s*\/Link/go)   { ++$Link   } ; 
        while (/\/Subtype\s*\/Widget/go) { ++$Widget } ;
        while (/\/S\s*\/Named/go)        { ++$Named  } ;
        while (/\/S\s*\/JavaScript/go)   { ++$Script } } 
    close (PDF) ; 
    print "               objects : $Object\n" ; 
    print "           annotations : $Annot\n" ; 
    print "                 links : $Link ($Named named / $Script scripts)\n" ; 
    print "               widgets : $Widget\n" }

#D We're done! All this actions and options are organized in
#D one large conditional:

                              ShowBanner       ;

if     ($UnknownOptions   ) { ShowHelpInfo     } # not yet done
elsif  ($ProcessReferences) { HandleReferences }
elsif  ($ProcessDocuments ) { HandleDocuments  }
elsif  ($ProcessSources   ) { HandleSources    }
elsif  ($ProcessSetups    ) { HandleSetups     }
elsif  ($ProcessTemplates ) { HandleEditorCues }
elsif  ($ProcessInfos     ) { HandleEditorCues }
elsif  ($ProcessFigures   ) { HandleFigures    }
elsif  ($ProcessLogFile   ) { HandleLogFile    }
elsif  ($PurgeFiles       ) { PurgeFiles       }
elsif  ($AnalyzeFile      ) { AnalyzeFile      }
elsif  ($ProcessHelp      ) { ShowHelpInfo     } # redundant
else                        { ShowHelpInfo     }

#D So far.
