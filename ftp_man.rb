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
	$store_path = node.elements[ "//storePath" ].text
	puts "store_path: #{$store_path }" if $debug
	puts

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
		 	ftp.chdir $ftp_file_dir
		 	#ftp.list ( $ftp_file ){ |file| puts file }
		 	##file exclusion example http://stackoverflow.com/questions/6182160/ruby-netftp-extract-filename-from-ftp-list-solved
			$ftp_file_list.each_index { |index|
				#puts "POS #{index} has #{$ftp_file_list[index].inspect}"
				ftp_file = $ftp_file_list[ index ]
				file_l = ftp.nlst ftp_file.f_name
				file_l.each do |file|
					file_n = file.inspect.to_s.delete('"')
					puts "Found: #{file_n}"
					if ftp_file.type.eql? "text"
						puts "Download a text file @ index: #{index + 1}" if $debug
						ftp.gettextfile file
					else
						puts "Download a binary file @ index: #{index + 1}" if $debug
						ftp.getbinaryfile file
					end
					puts "Saved #{File.size file} bytes."
					##Finally move file
					store_file file_n, $store_path #file_n.to_s.gsub('"', '')
				end
			}
			puts "End Download Sequence"
		end
		
		puts
		if upload_node.has_elements?
			puts "Start Upload Sequence."
			load_node upload_node, "upload"
			ftp.chdir $ftp_file_dir

			Dir.chdir $store_path
			$ftp_file_list.each_index { |index|
				up_file = $ftp_file_list[ index ]
				file_l = Dir.glob up_file.f_name
				file_l.each do |file|
					file_n = file.inspect.to_s.delete('"')
					puts "Found: #{file_n}"
					if up_file.type.eql? "text"
						puts "Upload a text file @ index: #{index + 1}" if $debug
						ftp.puttextfile file_n
					else
						puts "Upload a binary file @ index: #{index + 1}" if $debug
						ftp.putbinaryfile file_n
					end
				end
			}
			#ftp.list ( $ftp_file ){ |file| puts file }
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
