#!/usr/bin/env ruby
#
# This script will take a username, password, and optional comment and
#  write out a file with the password crypt()ed in the following format
#
#  username:password:comment
#
# Author: Dimitri Aivaliotis
# Date: 2012
#

# setup the command-line options
require 'optparse'
OptionParser.new do |o|
  o.on('-f FILE') { |file| $file = file }
  o.on('-u', "--username USER") { |u| $user = u }
  o.on('-p', "--password PASS") { |p| $pass = p }
  o.on('-c', "--comment COMM (optional)") { |c| $comm = c }
  o.on('-h') { puts o; exit }
  o.parse!
  if $user.nil? or $pass.nil?
    puts o; exit
  end
end

# initialize an array of ASCII characters to be used for the salt
ascii = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + [ ".", "/" ]
$lines = []

begin
  # read in the current http auth file
  File.open($file) do |f|
    f.lines.each { |l| $lines << l }
  end
rescue Errno::ENOENT
  # if the file doesn't exist (first use), initialize the array
  $lines = ["#{$user}:#{$pass}\n"]
end

# remove the user from the current list, since this is the one we're editing
$lines.map! do |line|
  unless line =~ /#{$user}:/
    line
  end
end

# generate a crypt()ed password
pass = $pass.crypt(ascii[rand(64)] + ascii[rand(64)])

# if there's a comment, insert it
if $comm
  $lines << "#{$user}:#{pass}:#{$comm}\n"
else
  $lines << "#{$user}:#{pass}\n"
end

# write out the new file, creating it if necessary
File.open($file, File::RDWR|File::CREAT) do |f|
  $lines.each { |l| f << l}
end
