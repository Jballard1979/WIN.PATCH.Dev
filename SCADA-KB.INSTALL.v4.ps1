#-- ************************************************************************************************************:
#-- ******************************************* INSTALL PATCH PATCHES ******************************************:
#-- ************************************************************************************************************:
#-- Author:   JBallard (JEB)                                                                                    :
#-- Date:     2022.5.10                                                                                         :
#-- Script:   SCADA-KB.INSTALL.v3.ps1                                                                           :
#-- Purpose:  A PowerShell script that installs Microsoft Windows KB Patches on remote SCADA systems.           :
#-- Usage:    Open the script in ISE & modify the $SCADASvrs var to the systems file needed.                    :
#-- Version:  1.0                                                                                               :
#-- ************************************************************************************************************:
#-- *********************************************** MODIFICATIONS **********************************************:
#-- ************************************************************************************************************:
#-- Editor:   JBallard (JEB)                                                                                    :
#-- Date:     2022.5.12                                                                                         :
#-- Purpose:  I added error conditions & console logging.                                                       :
#-- Version:  2.0                                                                                               :
#-- ************************************************************************************************************:
#-- Editor:   JBallard (JEB)                                                                                    :
#-- Date:     2023.10.05                                                                                        :
#-- Purspose: I added support for installing MSI & EXE file types.                                              :
#-- Purpose:  I added smart logging that addes info, warnings, & exception errors into a log file.              :
#-- Log Dir:  C:\0_SCRIPTS\KB.INSTALLER.Dev\0_LOGS\SCADA-PATCH.LOG.jeb                                          :
#-- Version:  3.0                                                                                               :
#-- ************************************************************************************************************:
#-- Editor:   JBallard (JEB)                                                                                    :
#-- Date:     2023.10.26                                                                                        :
#-- Purpose1: I added support for installing MSP & CAB file types using the switch expression handle. Will now  :
#-- Purpose1:   perform checks on multiple conditions, equivalent to multiple if statments.                     :
#-- Purpose2: I added ps remoting support that executes ps cmds on remote servers. Once the session is open,    :
#-- Purpsoe2:   the script imports the bit transfer module & sets the execution policy to REMOTE SIGNED.        :
#-- Version:  4.0                                                                                               :
#-- ************************************************************************************************************:
#-- ************************************************************************************************************:
#--
CD\
CLS
#--
#-- ********************************************************:
#-- DEFINE PARAMS, CONFIG PATHS, IMPORT CLASSES             :
#-- ********************************************************:
$SCADASvrs		= GET-CONTENT 'C:\0_SCRIPTS\KB.INSTALLER.Dev\SYS\NODNA.jeb'
$SCADAPatch		= 'KB5032197.msu'
#--
$PATCHReName	= $SCADAPatch -REPLACE ".{4}$"
$SCADASrc		= "C:\TEMP\PATCHES\$SCADAPatch"
$PSTOOLSrc		= 'C:\PSTOOLS\*'
$LOGPath    	= "C:\0_SCRIPTS\KB.INSTALLER.Dev\0_LOGS\SCADA-PATCH.LOG.jeb"
#--
#-- FUNCTION TO DEFINE LOG MSG:
function LOG-MESSAGE
{
    param ( [string]$LOGMsg, [string]$LOGPath, [string]$LOGLvl = "INFO" )
    $TIMEStamp = GET-DATE -FORMAT "yyyy-MM-dd : HH:mm:ss"
    $LOGEntry  = "$TIMEStamp - [$LOGLvl] - $LOGMsg"
    ADD-CONTENT -PATH $LOGPath -VALUE $LOGEntry
}
try
{
    #-- LOOP THRU SCADA SERVER ARRAY
    foreach ( $SCADASvr in $SCADASvrs ) 
	{
        $PSTOOLDest      = "\\$SCADASvr\C$\PSTOOLS\"
        $SCADADest       = "\\$SCADASvr\C$\TEMP\PATCHES"
        $SCADADestPatch  = "$SCADADest\$SCADAPatch"
        #--
        #-- CONFIGURE REMOTE POWERSHELL SESSIONS:
        LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - $SCADASvr - IMPORT BITS TRANSFER MODULE, & SET EXECUTION POLICY:" $LOGPath "INFO"
        WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - $SCADASvr - IMPORT BITS TRANSFER MODULE, & SET EXECUTION POLICY:" -FOREGROUNDCOLOR MAGENTA -BACKGROUNDCOLOR BLACK
        #--
        NEW-PSSESSION -COMPUTERNAME $SCADASvr
        ENTER-PSSESSION -COMPUTERNAME $SCADASvr
        ENABLE-PSREMOTING -FORCE
        IMPORT-MODULE BITSTRANSFER
        SET-EXECUTIONPOLICY -EXECUTIONPOLICY REMOTESIGNED -SCOPE CURRENTUSER -FORCE
        #--
        START-SLEEP -SECONDS 3
        EXIT-PSSESSION
        #--
        #-- TEST NETWORK CONNECTION TO SCADA SERVERS:
        if (-NOT ( TEST-CONNECTION -COMPUTERNAME $SCADASvr -COUNT 1 -QUIET ) -OR -NOT ( TEST-PATH -PATH $SCADADest ) ) 
		{
            LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - FAILED TO CONNECT TO $SCADASvr" $LOGPath "WARNING"
        }
		#--
        #-- CREATE DIRECTORY ON DESTINATION SCADA SERVER:
        NEW-ITEM -ITEMTYPE DIRECTORY -PATH $SCADADest -FORCE | OUT-NULL
        START-SLEEP -SECONDS 3
        # --
		#-- PROCESS BITS TRANSFER TO DEST SERVER:
        LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - TRANSFER PATCH & PSTOOLS TO $SCADASvr" $LOGPath "INFO"
        WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - TRANSFER PATCH & PSTOOLS TO $SCADASvr" -FOREGROUNDCOLOR GREEN -BACKGROUNDCOLOR BLACK
        #--
		START-BITSTRANSFER -SOURCE $PSTOOLSrc -DESTINATION $PSTOOLDest -DISPLAYNAME "PSTOOLS:"
		START-BITSTRANSFER -SOURCE $SCADASrc -DESTINATION $SCADADest -DISPLAYNAME "MS WIN PATCH - $SCADAPatch :"
		#--
		#-- UNBLOCK ALL PATCH INSTALLATION FILES:
        LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - UNBLOCK PATCH - $SCADAPatch" $LOGPath "INFO"
        WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - UNBLOCK PATCH - $SCADAPatch" -FOREGROUNDCOLOR MAGENTA -BACKGROUNDCOLOR BLACK
        #--
		GET-CHILDITEM -PATH $SCADADest -RECURSE | UNBLOCK-FILE
		#--
        #-- DETERMINE THE SCADA PATCH EXTENSION & APPLY PATCH TO SCADA SERVERS:
        $SCADAPatchExt = [System.IO.Path]::GetExtension($SCADAPatch).ToLower()
        switch ( $SCADAPatchExt ) 
		{
			#-- MSU - MICROSOFT UPDATE:
            ".msu"
			{
			    LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSU PATCH ON $SCADASvr" $LOGPath "INFO"
			    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSU PATCH ON $SCADASvr" -FOREGROUNDCOLOR GREEN -BACKGROUNDCOLOR BLACK
                #--
                &C:\PSTOOLS\PsExec64.exe -accepteula -s \\$SCADASvr WUSA $SCADASrc /QUIET /NORESTART
            }
			#-- MSP - MICROSOFT STANDALONE PATCH:
            ".msp" 
			{
			    LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSP PATCH ON $SCADASvr" $LOGPath "INFO"
			    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSP PATCH ON $SCADASvr" -FOREGROUNDCOLOR MAGENTA -BACKGROUNDCOLOR BLACK
                #--
                $MSPCmd    = "MSIEXEC.exe /p $SCADADest\$SCADAPatch /q /NORESTART"
                $MSPCmdBlk = [Scriptblock]::Create($MSPCmd)
                INVOKE-COMMAND -COMPUTERNAME $SCADASvr -SCRIPTBLOCK $MSPCmdBlk
            }
			#-- MSI - MICROSOFT STANDALONE INSTALLER:
            ".msi" 
			{
                LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSI PATCH ON $SCADASvr" $LOGPath "INFO"
			    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - INSTALL MSI PATCH ON $SCADASvr" -FOREGROUNDCOLOR GREEN -BACKGROUNDCOLOR BLACK
                #--
                $MSICmd    = "MSIEXEC /i $SCADADest\$SCADAPatch"
                $MSICmdBlk = [Scriptblock]::Create($MSICmd)
                INVOKE-COMMAND -COMPUTERNAME $SCADASvr -SCRIPTBLOCK $MSICmdBlk
            }
			#-- CAB - MICROSOFT CABINET FILE:
            ".cab" 
			{
                LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - INSTALL CAB PATCH ON $SCADASvr" $LOGPath "INFO"
			    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - INSTALL CAB PATCH ON $SCADASvr" -FOREGROUNDCOLOR MAGENTA -BACKGROUNDCOLOR BLACK
                #--
                &C:\PSTOOLS\PsExec64.exe -accepteula -s \\$SCADASvr DISM /ONLINE /ADD-PACKAGE /PACKAGEPATH:$SCADADest\$SCADAPatch /QUIET /NORESTART
            }
			#-- EXE - MICROSOFT EXECUTABLE:
            ".exe" 
			{
                LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - INSTALL EXE PATCH ON $SCADASvr" $LOGPath "INFO"
			    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - INSTALL EXE PATCH ON $SCADASvr" -FOREGROUNDCOLOR GREEN -BACKGROUNDCOLOR BLACK
                #--
                $EXECmd    = "MSIEXEC /p $SCADADest\$SCADAPatch /q"
                $EXECmdBlk = [Scriptblock]::Create($EXECmd)
                INVOKE-COMMAND -COMPUTERNAME $SCADASvr -SCRIPTBLOCK $EXECmdBlk
            }
            default
			{
                LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - UNSUPPORTED FILE EXTENSION DISCOVERED: $SCADAPatchExt" $LOGPath "WARNING"
                WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - UNSUPPORTED FILE EXTENSION DISCOVERED:" -FOREGROUNDCOLOR RED -BACKGROUNDCOLOR BLACK
            }
        }
		#-- ERROR CODE CONDITION:
        if ( $LASTEXITCODE -eq 123 ) 
		{
            LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - FAILED TO CONNECT TO SCADA SERVER: $SCADAServer" $LOGPath "WARNING"
            WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - FAILED TO CONNECT TO SCADA SERVER: $SCADAServer" -FOREGROUNDCOLOR RED -BACKGROUNDCOLOR BLACK
        }
		#-- SAFE CODE CONDITION:
        if ( $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010 -or $LASTEXITCODE -eq 1618 -or $LASTEXITCODE -eq 2359302 ) 
		{
            #-- PURGE PATCH FROM SCADA SERVER:
            LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - PURGING THE $SCADADestPatch PATCH FROM $SCADASvr" $LOGPath "INFO"
		    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - PURGING THE $SCADADestPatch PATCH FROM $SCADASvr" -FOREGROUNDCOLOR MAGENTA -BACKGROUNDCOLOR BLACK
            #--
		    REMOVE-ITEM $SCADADestPatch -FORCE -RECURSE -ERRORACTION SILENTLYCONTINUE
			#--
            #-- CONFIRM AUTOMATIC SERVER REBOOT:
            LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - PLEASE REBOOT THE $SCADASvr SERVER TO COMPLETE THE PATCHING PROCESS:" $LOGPath "INFO"
            WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - PLEASE REBOOT $SCADASvr TO COMPLETE THE PATCHING PROCESS:" -FOREGROUNDCOLOR GREEN -BACKGROUNDCOLOR BLACK
            #--
			#--RESTART-COMPUTER -COMPUTERNAME $SCADASvr -FORCE -CONFIRM:$true
        }
    }
}
catch 
{
    LOG-MESSAGE "$(GET-DATE -DISPLAYHINT TIME) - EXCEPTION ERROR: $_" $LOGPath "ERROR"
    WRITE-HOST "$(GET-DATE -DISPLAYHINT TIME) - EXCEPTION ERROR: $_" -FOREGROUNDCOLOR RED -BACKGROUNDCOLOR BLACK
}
#-- ********************************************************:
#-- END OF POWERSHELL SCRIPT                                :
#-- ********************************************************: