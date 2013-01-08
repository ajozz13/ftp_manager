#FTP Client to help download files
#usage: ftp_man profile.xml

require 'rexml/document'
require 'net/ftp'
require 'fileutils'

##variables
$debug = false
$ftp_server
$ftp_user
$ftp_pass
$ftp_file_dir
$ftp_file_list
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

def store_file file_name, sp
	print "Move file #{file_name}...."
	FileUtils.mv(file_name, sp+ "/" +file_name)
	puts "Done."
end

#Initialize component data
def load_node node, action
	$ftp_file_dir = date_check node.elements[ "//filedir" ].text
	puts "ftp_file_dir: #{$ftp_file_dir }" if $debug
	
	ftp_file_list_node = node.elements[ "//fileList" ]
	
	$ftp_file_list = Array.new
	ftp_file_list_node.each_element { |input_file|
		f = Input_ftp_file.new
		f.type = input_file.attributes[ "type" ]
		f.f_name = date_check input_file.text
		puts "ftp_file: #{f.f_name}" if $debug
		$ftp_file_list.push f

	}
	puts "Defined #{action} files: #{$ftp_file_list.size}." if $debug
	$store_path = date_check node.elements[ "//storePath" ].text
	puts "store_path: #{$store_path }" if $debug
	puts

end

#process action
def run_action upload_is_true, ftp_object

	ftp_object.chdir $ftp_file_dir
	Dir.chdir $store_path if upload_is_true
	
	$ftp_file_list.each_index { |index|
		ftp_file = $ftp_file_list[ index ]
		file_l = upload_is_true ? Dir.glob( ftp_file.f_name ) : ftp_object.nlst( ftp_file.f_name )

		file_l.each do |file|
			file_n = file.inspect.delete('"')
			print "File: #{file_n}"
			print "..@ #{ index + 1 }.."
			print upload_is_true ?  "upload " : "download " if $debug
			if ftp_file.type.eql? "text"
				print "text mode.." if $debug
			#	upload_is_true ? ftp_object.puttextfile(file_n) : ftp_object.gettextfile(file)
			else
				print "binary mode.." if $debug
				upload_is_true ? ftp_object.putbinaryfile(file_n) : ftp_object.getbinaryfile(file)
			end	
			puts ".Done."
			
			if upload_is_true and $debug
				puts "Directory Listing"
				ftp_object.list('*') { |f| puts f }
			else
				puts "Saved #{File.size file} bytes."
				##Finally move file
				store_file file_n, $store_path #file_n.to_s.gsub('"', '')
			end
		end
	}
end

##CLASSES
class Input_ftp_file
	attr_accessor :f_name, :type
	
	def initialize
	end
end

##MAIN
error_msg "Usage: #{ $0 } format_file.xml", 1 unless ARGV.length > 0
error_msg "Usage: #{ $0 } format_file.xml", 1 unless File.file? ARGV[ 0 ]

begin
	$debug = ARGV.include? "-d"
	puts "FTP Program Started for #{ ARGV[0] }" if $debug
	conf_xml = REXML::Document.new( File.read( ARGV[ 0 ] ) )
	
	#READ XML FILE
	$ftp_server = conf_xml.root.elements[ "//server" ].text
	puts "ftp_server: #{$ftp_server }" if $debug
	
	$ftp_user = set_var_or_nil conf_xml.root.elements[ "//user" ]
	puts "ftp_user: #{$ftp_user }" if $debug
	
	$ftp_pass = set_var_or_nil conf_xml.root.elements[ "//pass" ]
	puts "ftp_pass: #{$ftp_pass }" if $debug
	
	download_node = conf_xml.root.elements[ "//download" ]
	upload_node = conf_xml.root.elements[ "//upload" ]

	puts "Access FTP"

	ftp = Net::FTP.open( $ftp_server ) do |ftp|
		ftp.passive = true
		if $ftp_user.nil?
			ftp.login
		else
			ftp.login $ftp_user, $ftp_pass
		end

		puts
		
		 if download_node.has_elements?
		 	puts "Start Download Sequence."
		 	load_node download_node, "download"
		 	run_action false, ftp
			puts "End Download Sequence"
		end

		if upload_node.has_elements?
			puts "Start Upload Sequence."
			load_node upload_node, "upload"
			run_action true, ftp
			puts "End Upload Sequence."
		end
		puts
		puts "Close FTP"
		ftp.close
	end

rescue Exception => e
	error_msg "Exception: #{e}", 2
end
exit 0
