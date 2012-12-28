#FTP Client to help download files
#usage: ftp_man profile.xml

require 'rexml/document'
require 'net/ftp'
require 'fileutils'

##variables
debug = false
$ftp_server
$ftp_user
$ftp_pass
$ftp_file_dir
$ftp_file
$store_path


##functions
def error_msg msg, exit_code
	STDERR.write msg
	puts
	exit exit_code unless exit_code < 1
end

def set_var_or_nil input_node	
	begin
		input_node.text
	rescue Exception => e
		return nil
	end
end

def date_check input
	Time.new.strftime input
end

##MAIN
error_msg "Usage: #{ $0 } format_file.xml", 1 unless ARGV.length > 0
error_msg "Usage: #{ $0 } format_file.xml", 1 unless File.file? ARGV[ 0 ]

begin
	debug = ARGV.include? "-d"
	puts "FTP Program Started for #{ ARGV[0] }" if debug
	conf_xml = REXML::Document.new( File.read( ARGV[ 0 ] ) )
	
	#READ XML FILE
	$ftp_server = conf_xml.root.elements[ "//server" ].text
	puts "ftp_server: #{$ftp_server }" if debug
	
	$ftp_user = set_var_or_nil conf_xml.root.elements[ "//user" ]
	puts "ftp_user: #{$ftp_user }" if debug
	
	$ftp_pass = set_var_or_nil conf_xml.root.elements[ "//pass" ]
	puts "ftp_pass: #{$ftp_pass }" if debug
	
	$ftp_file_dir = date_check conf_xml.root.elements[ "//filedir" ].text
	puts "ftp_file_dir: #{$ftp_file_dir }" if debug
	
	$ftp_file = date_check conf_xml.root.elements[ "//file" ].text
	puts "ftp_file: #{$ftp_file }" if debug
	
	$store_path = conf_xml.root.elements[ "//storePath" ].text
	puts "store_path: #{$store_path }" if debug
	puts

	puts "Access FTP"
	
	ftp = Net::FTP.open( $ftp_server ) do |ftp|
		ftp.passive = true
		if $ftp_user.nil?
			ftp.login
		else
			ftp.login $ftp_user, $ftp_pass
		end
		
		ftp.chdir $ftp_file_dir
		ftp.list ( $ftp_file ){ |file| puts file }
		puts
		ftp.gettextfile $ftp_file
	end
	
	##Finally move file
	#FileUtils.mv('/tmp/your_file', '/opt/new/location/your_file')


rescue Exception => e
	error_msg "Exception: #{e}", 2
end