#!/usr/bin/env ruby

###############################################################################
# Copyright (c) 2010, SugarCRM, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of SugarCRM, Inc. nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL SugarCRM, Inc. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###############################################################################

###############################################################################
# Needed Ruby libs:
###############################################################################
require 'Soda'
require 'getoptlong'
require 'libxml'
require 'commonwatir'
require 'SodaReportSummery'
require 'pp'

###############################################################################
# SodaSuite -- Class
#     This is a simple class to run soda tests.
#
# Params:
#     params: This is a hash of parameters to pass in.
#
# Valid params:
#     browser => [true, false]
#     flavor => [ce pro, ent]
#     savehtml => [true, false]
#     hijacks => {}
#     resultsdir => some directory
#     profile => a firefox profile name
#
# Notes:
#     It seems over kill to have this as a class, but I can't think of a good
#     enough reason to change it.  Yet....
#
###############################################################################
class SodaSuite
	attr_accessor :scripts, :soda

   NEEDED_SODA_VERSION = 1.0

   def initialize(params)
      @SodaParams = params

	   if (NEEDED_SODA_VERSION != Soda::SODA_VERSION)
         print "(!)Failed matching Soda Class Versions!\n" +
            "--)Required Version: #{NEEDED_SODA_VERSION}\n" +
            "--)Found Version   : #{Soda::SODA_VERSION}\n\n"
         exit(-1)
      end

      if ("#{CommonWatir::VERSION}" != "#{Soda::SODA_WATIR_VERSION}")
         print "(!)Failed matching installed Watir version to Soda's" +
            " required version!\n" +
            "--)Required Version: #{Soda::SODA_WATIR_VERSION}\n" +
            "--)Found Version   : #{CommonWatir::VERSION}\n\n"
         exit(-1)
      end
	end

###############################################################################
# ExecuteSodaTest -- Method
#     This method will execute a single specific soda XML test.
#
# Params:
#     sodatest: This is the soda XML test to execute.
#
# Results:
#     reutns a SodaReport object...  THis should be changed later!
#
###############################################################################
	def ExecuteSodaTest(sodatest)
      soda = nil
      result = {}
      failed_tests = nil
      
      soda = Soda::Soda.new(@SodaParams)
      result['error'] = soda.run(sodatest)
      result['failed_tests'] = soda.GetFailedTests()
      soda = nil

      return result
	end

###############################################################################
# ExecuteTestSuite -- Method
#     This method executes a test suite in a single browsers, really this is
#     a hack so all the old soda tests still work without lots of mods...
#
# Prams:
#     suite: This is an array of tests to run.
#     rerun: true/false, tells soda that these tests are reruns.
#
# Results:
#     None.
#
###############################################################################
   def ExecuteTestSuite(suite, rerun = false)
      soda = nil
      master_result = 0
      result = nil
      
      soda = Soda::Soda.new(@SodaParams)
      suite.each do |test|
         result = soda.run(test, rerun)
         if (result == -1)
            SodaUtils.PrintSoda("Failed executing test file: #{test}!\n",
               SodaUtils::ERROR)
            master_result = -1
         
            begin
               soda.browser.close()
            rescue Exception => e
               print "Exception: #{e.message}\n"
            ensure
            end
            soda = Soda::Soda.new(@SodaParams)
         end
      end

      begin
         soda.browser.close()
      rescue Exception => e
         print "Exception: #{e.message}\n"
      ensure
      end

      soda = nil
      return master_result
   end

###############################################################################
# Execute -- Medhod
#     This method executes a soda XML scripts.  If the files is a directory it
#     will execute all XML scripts in that directory, if it is a file it will 
#     execute just that script. 
#
# Params:
#     file: This is the soda test file or a directory containing soda test
#        files.
#
# Results:
#     Returns -1 on error or 0 on success.
#
###############################################################################
	def Execute(file)
      report = nil

		if (File.directory?(file))
			scriptFiles = File.join("#{file}", "*.xml")
			files = Dir.glob(scriptFiles)
			
         for testfile in files
            SodaUtils.PrintSoda("Executing test file: #{testfile}\n")
				report = ExecuteSodaTest(testfile)
            
            if (report['error'] == -1)
               return report
            end
			end
		elsif(File.file?(file))
            SodaUtils.PrintSoda("Executing test file: #{file}\n")
				report = ExecuteSodaTest(file)
            SodaUtils.PrintSoda("Finished executing test file: #{file}\n")
            
            if (report['error'] == -1)
               return report
            end
	   else
            SodaUtils.PrintSoda("Failed To Load File: '#{file}'\n", 
               SodaUtils::ERROR)
		end

      return report
	end
  
end

###############################################################################
# PrintHelp --
#     This function will print the help message for this script, then exit
#     with an error code, which is anything other then 0.
#
# Params:
#     None.
#
# Results:
#     None.
#
###############################################################################
def PrintHelp
   hlp_msg = <<HLP
#{$0}
Usage:
   #{$0} --browser="supported browser" --test="sodatest1.xml" 
      --test="sodatest2.xml" ...

Required Flags:
   --browser: This is any of the following supported web browser name.
      [ firefox, safari, ie ]
   
   --test: This is a soda test file.  This argument can be used more then
      once when there are more then one soda tests to run.

Optional Flags:
   --flavor: This tells Soda which flavor of Sugar you are testing.
      [ent, ce, pro, express]  The default is ent when this flag is not set.
   
   --savehtml: This flag will cause html pages to be saved when there is an
      error testing the page.

   --hijack: This is a key/value pair that is used to hi jack any csv file
      values of the same name.  The key and value are split using "::".  
      Example: --hijack="username::sugaruser"

   --resultdir: This allows you to override the default results directory.

   --profile: The name of a Firefox profile to use, other then the default.

   --gvar: This is a global var key/value pair to be injected into Soda.
      The key and value are split using "::".
      Example: --gvar="slayerurl::http://www.slayer.net"

   --suite: This is a Soda suite xml test file.

   --summery: This the the name of the summery file to output.

   --debug: This turns on debug messages.

   --rerun: This will cause failed tests to be rerun.

   --sugarwait: This enables the auto sugarwait functionality for every click.

   --help:  Prints this message and exits.

HLP
   
   print "#{hlp_msg}"
   exit(1)

end

###############################################################################
# InstallSigs -- Function
#     This function installs trap handlers to kill the ruby process.
#
# Params:
#     None.
#
# Results:
#     None.
#
# Notes:
#     This is mostly useless as the Watir code doesn't respect signals at all.
#
###############################################################################
def InstallSigs
   sigs = [
      "INT",
      "ABRT",
      "KILL"
   ]

   sigs.each do |s|
      Signal.trap(s, proc { Process.kill(INT, Process.pid) } )
   end

end

###############################################################################
# AddCmdArg2Hash - function
#
#
###############################################################################
def AddCmdArg2Hash(arg, hash)
   data = arg.split(/::/)

   if (data.length == 2)
      hash["#{data[0]}"] = "#{data[1]}"
   end

   return hash
end

###############################################################################
# CreateResultsDir - function
#     Creates needed results dir.
# 
# Params:
#     dir: This is the directory to create.
#
# Results:
#     returns 0 on success, or -1 on error.
#
###############################################################################
def CreateResultsDir(dir)
   result = -1

   if (File.directory?(dir))
      return 0
   end

   begin
      FileUtils::mkdir_p(dir)
      result = 0
   rescue Exception => e
      print "(!)Failed to create results directory: #{dir}!\n"
      print "--)Reason: #{e.message}\n\n"
      result = -1
   end
   
   return result

end

###############################################################################
# GetFileSetFiles - function
#     This function expands filesets into a list of files.
#
# Params:
#     dir: The directory to get soda xml files from.
#
# Results:
#     returns an array of files.
#
###############################################################################
def GetFileSetFiles(dir)
   files = nil
   test_files = []

   files = File.join("#{dir}", "*.xml")
   test_files = Dir.glob(files)

   return test_files
end

###############################################################################
# GetSuiteTestFiles - function
#     This function reads a sode suite file and creates a list of tests from
#     the file, by expanding on filesets and files.
#
# Params:
#     suite_file: This is the suite xml file.
#
# Results:
#     returns an array of files.
#
###############################################################################
def GetSuiteTestFiles(suite_file)
   test_files = []  
   parser = nil
   doc = nil

   parser = LibXML::XML::Parser.file(suite_file)
   doc = parser.parse()
   
   doc.root.each do |node|
      if (node.name != 'script')
         next
      end

      attrs = node.attributes()
      attrs.each do |a|
         h = attrs.to_h()
         if (h.key?("file"))
            test_files.push(h['file'])
         elsif (h.key?('fileset'))
            fs = h['fileset']
            if (File.directory?(fs))
               fs_set = GetFileSetFiles(fs)
               test_files.concat(fs_set)
               fs_set = nil
            end
         end
      end
   end

   return test_files
end

###############################################################################
# ReadConfigFile - function
#     This functions reads the soda config file into a hash.
#
# Params:
#     configfile: This is the config xml file to read.
#
# Results:
#     Returns a hash containing the config file parsed into sub hashes and
#     arrays.
#
###############################################################################
def ReadConfigFile(configfile)
   parser = nil
   doc = nil
   data = {
      "gvars" => {},
      "cmdopts" => [],
      "errorskip" => []
   }

   parser = LibXML::XML::Parser.file(configfile)
   doc = parser.parse()

   doc.root.each do |node|
      attrs = node.attributes()
      attrs = attrs.to_h()
      name = attrs['name']
      content = node.content()
      case node.name
         when "errorskip"
            data['errorskip'].push("#{attrs['type']}")
         when "gvar"
            data['gvars']["#{name}"] = "#{content}"
         when "cmdopt"
            data['cmdopts'].push({"#{name}" => "#{content}"})
         when "text"
            next
         else
            SodaUtils.PrintSoda("Found unknown xml tag: \"#{node.name}\"!\n", 
               SodaUtils::ERROR)
      end
   end
   
   return data
end

###############################################################################
# Main --
#     This is a C like main function that is being used to help with debugging
#     and code readabality in general.  Yes spelling errors in comments are
#     lame...
#
# Params:
#     None.
#
# Results:
#     A;lways returns 0
#
###############################################################################
def Main
   master_result = 0
   result = 0
   config_file = "soda-config.xml"
   config_data = nil
   sweet = nil
   verbose = false
   browser = nil
   flavor = "ent"
   savehtml = false
   resultsdir = nil
   profile = nil
   rerun_failed_test = false
   failed_tests = []
   test_files = []
   hijacks = {}
   params = {
      'sugarwait' => false,
      'verbose' => false,
      'browser' => nil,
      'debug' => false,
      'flavor' => "ent",
      'savehtml' => false,
      'resultsdir' => nil,
      'profile' => nil,
      'summaryfile' => nil,
      'suites' => [],
      'test_files' => [],
      'hijacks' => {},
      'gvars' => [],
      'errorskip' => []
   }

   # turn off ruby i/o buffering #
   $stdout.sync = true;
   $stderr.sync = true;

   InstallSigs()
   
   if (File.file?(config_file))
      config_data = ReadConfigFile(config_file)
      params['gvars'] = config_data['gvars']
      params['errorskip'] = config_data['errorskip']
   else
      config_data = nil
   end
  
   config_data['cmdopts'].each do |o|
      if (o.key?('browser'))
         params['browser'] = o['browser']
         break
      end
   end

   begin
      opts = GetoptLong.new(
               [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
               [ '--browser', '-b', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--debug', '-d', GetoptLong::NO_ARGUMENT ],
               [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
               [ '--test', '-t', GetoptLong::REQUIRED_ARGUMENT ],
               [ '--flavor', '-f', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--hijack', '-j', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--savehtml', '-s', GetoptLong::NO_ARGUMENT ],
               [ '--resultdir', '-r', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--profile', '-p', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--gvar', '-g', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--suite', '-u', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--summery', '-k', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--rerun', '-e', GetoptLong::OPTIONAL_ARGUMENT ],
               [ '--sugarwait', '-w', GetoptLong::OPTIONAL_ARGUMENT ]
            )

      opts.quiet = true
      opts.each do |opt, arg|
         case opt
            when "--sugarwait"
               params['sugarwait'] = true
            when "--help"
               PrintHelp()
            when "--browser"
               params['browser'] = arg
            when "--debug"
               params['debug'] = true
            when "--verbose"
               params['verbose'] = true
            when "--test"
               params['test_files'].push(arg)
            when "--flavor"
               params['flavor'] = arg
            when "--savehtml"
               params['savehtml'] = true
            when "--hijack"
               params['hijacks'] = AddCmdArg2Hash(arg, hijacks)
            when "--resultdir"
               params['resultsdir'] = arg
            when "--profile"
               params['profile'] = arg
            when "--suite"
               params['suites'].push(arg)
            when "--summery"
               params['summaryfile'] = arg.to_s()
            when "--gvar"
               params['gvars'] = AddCmdArg2Hash(arg, params['gvars'])
            when "--rerun"
               rerun_failed_test = true
         end
      end
   rescue Exception => e
      SodaUtils.PrintSoda("Error: #{e.message}\n", SodaUtils::ERROR)
      exit(-1)
   end

   if (!params['browser'])
      SodaUtils.PrintSoda("Missing argument --browser!\n\n", 1)
      PrintHelp()
   end

   if ( (params['test_files'].length < 1) && (params['suites'].length < 1) )
      SodaUtils.PrintSoda("Missing soda tests to run, try using --test=" +
         "<sodatestfile>!\n\n")
      PrintHelp()
   end

   SodaUtils.PrintSoda("SodaSuite Settings:\n--)Browser:" +
      " #{params['browser']}\n--)Debug: #{params['debug']}\n--)Verbose:"+
      " #{params['verbose']}\n" +
      "--)Watir Version: #{CommonWatir::VERSION}\n")
   SodaUtils.PrintSoda("Starting testing...\n")

   if (params['resultsdir'] != nil)
      err = CreateResultsDir(params['resultsdir'])
      print "Result: #{err}\n"
      if (err != 0)
         exit(-1)
      end
   
      if (params['summaryfile'] == nil)
         params['summaryfile'] = "#{params['resultsdir']}/summery.html"
      end

   end

   if (params['suites'].length > 0)
      sweet = SodaSuite.new(params)
      params['suites'].each do |swt|
         result = sweet.ExecuteTestSuite(swt)
         if (result != 0) 
            master_result = -1
         end
      end
   end

   if (params['test_files'].length > 0)
      sweet = SodaSuite.new(params)
      params['test_files'].each do |testfile|
         result = sweet.Execute(testfile)
         failed_tests = failed_tests.concat(result['failed_tests']) 

         if (result['error'] != 0)
            master_result = -1
            SodaUtils.PrintSoda("Failed executing soda test:"+
               "\"#{testfile}\"!\n")
            sweet = SodaSuite.new(params)
         end
      end
   end

   # see if we should rerun failed tests #
   if (rerun_failed_test && failed_tests.length > 0)
      SodaUtils.PrintSoda("Rerunning failed tests.\n")
      sweet.ExecuteTestSuite(failed_tests, true)
      SodaUtils.PrintSoda("Finished rerunning failed tests.\n")
   end

   if (params['resultsdir'] != nil)
      begin
         summery = SodaReportSummery.new(params['resultsdir'], 
            params['summaryfile'], true)
      rescue Exception => e
         print "Error: calling: SodaReportSummery!\n"
         print "StackTrace: #{e.backtrace}\n\n"
         exit(-1)
      ensure
      end
   end

   SodaUtils.PrintSoda("Finished testing.\n")
   exit(master_result)
end

###############################################################################
# Start executing code here -->
###############################################################################
   Main()
   exit(0)
   


