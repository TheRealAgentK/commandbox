/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* The CommandBox Shell Object that controls the shell
*/
component accessors="true" singleton {

	/**
	* The java reader class.
	*/
	property name="reader";
	/**
	* The shell version number
	*/
	property name="version";
	
	/**
	* Print utility for outputting ANSI-formatted text
	*/
	property name="print" inject="print";
	/**
	* This helps actually process the commands
	*/
	property name="commandService" inject="CommandService";
	/**
	* Creating the reader is messy, so I abstracted it
	*/
	property name="readerFactory" inject="ReaderFactory";
	/**
	* The java system class.
	*/
	property name="system" inject="system";
	
	property name="initialDirectory" inject="userDir";
	property name="homeDir" inject="homeDir";
	property name="tempDir" inject="tempDir";
	property name="CR" inject="CR";
	property name="formatterUtil" inject="Formatter";
	property name="logger" 	inject="logbox:logger:{this}";


	/**
	 * constructor
	 * @inStream.hint input stream if running externally
	 * @printWriter.hint output if running externally
 	**/
	function init( inStream, printWriter ) {

		// Version is stored in cli-build.xml. Build number is generated by Ant.
		// Both are replaced when CommandBox is built.
		variables.version = "@build.version@.@build.number@";
		// Init variables.
		variables.keepRunning = true;
		variables.reloadshell = false;
		
		// Save these for onDIComplete()
		variables.initArgs = arguments;
						
    	return this;
	}

	/**
	 * Finish configuring the shell
	 **/
	function onDIComplete() {
		variables.pwd = initialDirectory;
		
		variables.reader = readerFactory.getInstance( argumentCollection = variables.initArgs  );
		
		variables.shellPrompt = print.green( "CommandBox> ");
		
		// set and recreate temp dir
		setTempDir( variables.tempdir );
		
		// load commnands Async
		thread name="initCommands-#createUUID()#"{
			variables.commandService.configure();
		}
		
	}

	/**
	 * sets exit flag
	 **/
	function exit() {
    	variables.keepRunning = false;
		return "Peace out!";
	}


	/**
	 * sets reload flag, relaoded from shell.cfm
	 * @clear.hint clears the screen after reload
 	 **/
	function reload(Boolean clear=true) {
		if( arguments.clear ){
			reader.clearScreen();
		}
		variables.reloadshell = true;
    	variables.keepRunning = false;
	}

	/**
	 * returns the current console text
 	 **/
	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	/**
	 * sets prompt
	 * @text.hint prompt text to set
 	 **/
	function setPrompt(text="") {
		if(text eq "") {
			text = variables.shellPrompt;
		} else {
			variables.shellPrompt = text;
		}
		reader.setDefaultPrompt( variables.shellPrompt );
		return "set prompt";
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask( message ) {
		var input = "";
		input = reader.readLine( message );
		reader.setDefaultPrompt( variables.shellPrompt);
		return input;
	}


	/**
	 * Wait until the user's next keystroke
	 * @message.message An optional message to display to the user such as "Press any key to continue."
 	 **/
	function waitForKey( message='' ) {
		var key = '';
		if( len( message ) ) {
			printString( message );
    		reader.flushConsole();
		}
		key = getReader().readVirtualKey();
		reader.setDefaultPrompt( variables.shellPrompt );
		return key;
	}

	/**
	 * clears the console
 	 **/
	function clearScreen() {
		reader.clearScreen();
		/*
		// Almost works on Windows, but doesn't
		// clear text backgroun
    	reader.printString( '[2J' );
    	reader.printString( '[1;1H' );
    	reader.flushConsole();
		*/
	}

	/**
	 * Get's terminal width
  	 **/
	function getTermWidth() {
       	return getReader().getTermwidth();
	}

	/**
	 * Get's terminal height
  	 **/
	function getTermHeight() {
       	return getReader().getTermheight();
	}

	/**
	 * returns the current directory
  	 **/
	function pwd() {
    	return pwd;
	}

	/**
	 * sets the shell home directory
	 * @directory.hint directory to use
  	 **/
	function setHomeDir( required directory ){
		variables.homedir = directory;
		setTempDir( variables.homedir & "/temp" );
		return variables.homedir;
	}

	/**
	 * returns the shell home directory
  	 **/
	function getHomeDir() {
		return variables.homedir;
	}

	/**
	 * returns the shell artifacts directory
  	 **/
	function getArtifactsDir() {
		return getHomeDir() & "/artifacts";
	}

	/**
	 * sets and renews temp directory
	 * @directory.hint directory to use
  	 **/
	function setTempDir(required directory) {
        lock name="clearTempLock" timeout="3" {
		    variables.tempdir = directory;
		        
        	// Delete temp dir
	        var clearTemp = directoryExists(directory) ? directoryDelete(directory,true) : "";
	        
	        // Re-create it. Try 3 times.
	        var tries = 0;
        	try {
        		tries++;
		        directoryCreate( directory );
        	} catch (any e) {
        		if( tries <= 3 ) {
					logger.info( 'Error creating temp directory [#directory#]. Trying again in 500ms.', 'Number of tries: #tries#' );
        			// Wait 500 ms and try again.  OS could be locking the dir
        			sleep( 500 );
        			retry;
        		} else {
					logger.info( 'Error creating temp directory [#directory#]. Giving up now.', 'Tried #tries# times.' );
        			printError(e);        			
        		}
        	}
        }
    	return variables.tempdir;
	}

	/**
	 * returns the shell temp directory
  	 **/
	function getTempDir() {
		return variables.tempdir;
	}

	/**
	 * changes the current directory
	 * @directory.hint directory to CD to
  	 **/
	function cd(directory="") {
		directory = replace(directory,"\","/","all");
		if(directory=="") {
			pwd = initialDirectory;
		} else if(directory=="."||directory=="./") {
			// do nothing
		} else if(directoryExists(directory)) {
	    	pwd = directory;
		} else {
			return "cd: #directory#: No such file or directory";
		}
		return pwd;
	}

	/**
	 * prints string to console
	 * @string.hint string to print (handles complex objects)
  	 **/
	function printString(required string) {
		if(!isSimpleValue(string)) {
			systemOutput("[COMPLEX VALUE]\n");
			writedump(var=string, output="console");
			string = "";
		}
    	reader.printString(string);
    	reader.flushConsole();
	}

	/**
	 * runs the shell thread until exit flag is set
	 * @input.hint command line to run if running externally
  	 **/
    function run( input="" ) {
        var mask = "*";
        var trigger = "su";
        
		// init reload to false, just in case
        variables.reloadshell = false;

		try{
	        if( arguments.input != "" ){
	        	 arguments.input &= chr(10);
	        	var inStream = createObject( "java", "java.io.ByteArrayInputStream" ).init( arguments.input.getBytes() );
	        	reader.setInput( inStream );
	        }
	        reader.setBellEnabled( false );

	        var line ="";
	        variables.keepRunning = true;
			reader.setDefaultPrompt( variables.shellPrompt );

	        while( variables.keepRunning ){

				if( input != "" ){
					variables.keepRunning = false;
				}
				reader.printNewLine();
				try {
					// Shell stops on this line while waiting for user input
		        	line = reader.readLine();
				} catch( any er ) {
					printError( er );
					continue;
				}

	            // If we input the special word then we will mask the next line.
	            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
	                line = reader.readLine("password> ", javacast("char",mask));
	            }

	            // If there's input, try to run it.
				if( len(trim(line)) ) {

					try{
						callCommand(line);
					} catch (any e) {
						printError(e);
					}
				}    	 

	        } // end while keep running

		} catch( any e ){
			printError( e );
		}
		return variables.reloadshell;
    }

	/**
	 * call a command
 	 * @command.hint command name
 	 **/
	function callCommand( String command="" )  {
		var result = commandService.runCommandLine( command );
		if(!isNull( result ) && !isSimpleValue( result )) {
			if(isArray( result )) {
				return reader.printColumns(result);
			}
			result = formatterUtil.formatJson(serializeJSON(result));
			printString( result );
		} else if( !isNull( result ) ) {
			printString( result );
		}
	}


	/**
	 * print an error to the console
	 * @err.hint Error object to print (only message is required)
  	 **/
	function printError(required err) {
		logger.error( '#err.message# #err.detail#', err.stackTrace );
		reader.printString(print.boldRedText( "ERROR: " & formatterUtil.HTML2ANSI(err.message) ) );
		reader.printNewLine();
		if( structKeyExists( err, 'detail' ) ) {
			reader.printString(print.boldRedText( formatterUtil.HTML2ANSI(err.detail) ) );
			reader.printNewLine();
		}
		if (structKeyExists( err, 'tagcontext' )) {
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						if( idx > 1 ) {
							reader.printString( print.boldCyanText( "called from " ) );
						}
						reader.printString(print.boldCyanText( "#tc.template#: line #tc.line##CR#" ));
						reader.printString( print.text( formatterUtil.HTML2ANSI( tc.codeprinthtml ) ) );
					}
				}
			}
		}
		if( structKeyExists( err, 'stacktrace' ) ) {
			reader.printString( err.stacktrace );
		}
		reader.printNewLine();
	}

}
