#!/usr/bin/perl -w
use strict;
use MIME::Parser;
use MIME::Entity;
use MIME::Body;

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

##################### Configuration #########################
#############################################################
# Change these variables to suit your needs.
#

#Change this to where you want files saved.  It should
#be readable by whatever user this script is running as,
#probably nobody or whatever Postfix runs as.
#my $dest = "/opt/misc/mailpics/";
my $dest = "./";

#This isn't a bulletproof means of security, but it's
#a good first measure.  If defined, this sets up a 
#whitelist of addresses to accept mails from.  One
#per line.  This should not be readable, but not writeable
#by the user the script is run as.
my $whitelist = "./whitelist.txt";

#Maximum number of attachments.  Leave as 0 for unlimited.
#If there are more than this number, we'll just take the
#first however many is given here and disregard the rest.
my $max_attachments = 0;

#Maximum attachment size.  The total attachment size should
#be able to be limited by the mail server; this is the max
#any single attachment can be.  Number is in kilobytes.
my $max_size = 4096;

#MIME types we'll accept as attachments
my @attypes= qw(application/msword
                application/pdf
                application/gzip
                application/tar
                application/tgz
                application/zip
                audio/alaw-basic
                audio/vox
                audio/wav
                image/bmp
                image/gif
                image/jpeg
                text/html
                text/plain
                text/vxml
);

#############################################################
#############################################################

#Variables
my($i, $x, $subentity, @attachments, $attach_count);

#Make a new parser for the message
my $parser = new MIME::Parser;

$parser->ignore_errors(1);
$parser->output_to_core(1);

#Read and Parse
my $entity = $parser->parse(\*STDIN);
my $error = ($@ || $parser->last_error);

#Get the header
my $header = $entity->head();

#Get the sender
my $from = $header->get('From');

#Check the sender
if(!addrCheck($from)) {
   exit 0;
}

#Go through message to find attachments
if($entity->parts > 0) {
   $attach_count = 0;
   
   for($i = 0; $i < $entity->parts; $i++) {
      $subentity = $entity->parts($i);
      
      foreach $x (@attypes) {
         
         if($subentity->mime_type =~ m/$x/i) {
            my $handle = $subentity->bodyhandle;
            my $attachment = $handle->as_string;
            my $name = $subentity->head->mime_attr('content-disposition.filename');
            
            #Get size
            my $kbytes;
            {
               use bytes;
               $kbytes = length($attachment) / 1024;
            }
            
            if(defined($name) && $kbytes <= $max_size) {
               push(@attachments, { name => $name, contents => $attachment });
               $attach_count++;
            }
         }
      }
      
      if($max_attachments > 0 && $attach_count > $max_attachments - 1) {
         last;
      }
      
   }
}

#Write attachments to file
foreach(@attachments) {
   my %file = %{$_};
   my $name;
   
   #Check if the file exists already.  If it does,
   #append the Unix timestamp.
   if(-e $dest . $file{name}) {
      $name = $dest . $file{name} . "." . time();
   }
   else {
      $name = $dest . $file{name};
   }
   
   open(FILE, ">" . $name);
   
   print FILE $file{contents};
   print "$file{name}\n";
   close(FILE);
   chmod("0666", $name);
}

#Validate an Email address to see if it's in
#the whitelist.  If it is, or if there is no
#whitelist, return 1.  Otherwise, return 0.
sub addrCheck {
   my $addr = shift;
   if(!$whitelist) {
      return 1;
   }
   else {
      if(open(WHTLST, $whitelist)) {
         while(<WHTLST>) {
            $/ = "\n";
            chomp($_);
            if($addr =~ m/$_/) {
               close(WHTLST);
               return 1;
            }
            else {
               close(WHTLST);
               return 0;
            }
         }
         close(WHTLST);
      }
      else {
         return 1;
      }
   }
}
