# Plugin for Foswiki - The Free and Open Source Wiki, https://foswiki.org/
#
# SysinfoPlugin is Copyright (C) 2025-2026 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::SysinfoPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox ();
use Sys::CpuLoad ();
use Sys::MemInfo ();
#use Data::Dump qw(dump);

use constant TRACE => 0; # toggle me

sub new {
  my $class = shift;

  my $this = bless({
    @_
  }, $class);


  return $this;
}

sub finish {
  my $this = shift;

   undef $this->{_sysinfo};
   undef $this->{_cpuLoad};
   undef $this->{_meminfo};
}

sub allowed {
  my $this = shift;

  unless (defined $this->{allowed}) {
    $this->{allowed} = 1;
    $this->{allowed} = 0 if $Foswiki::cfg{SysinfoPlugin}{AdminOnly} && !Foswiki::Func::getContext()->{isadmin};
  }

  return $this->{allowed};
}

sub df {
  my ($this, $params) = @_;

  _writeDebug("called df()");

  my $human = Foswiki::Func::isTrue($params->{human}, 0);
  my $blockSize = $params->{blocksize} // $human ? 1 : 1024;
  my $filePath = $params->{_DEFAULT} // $params->{filepath} // '';
  my $prec = $params->{precision} // 2;

  #_writeDebug("blockSize=$blockSize");
  #_writeDebug("human=$human");
  #_writeDebug("filePath=$filePath");

  my $cmd = $Foswiki::cfg{SysinfoPlugin}{DiskFreePathCmd} // '/usr/bin/df --block-size=%BLOCKSIZE|N%';
  $cmd .= ' %FILEPATH|F%' if $filePath;

  _writeDebug("cmd=$cmd");

  my ($output, $exit, $error) = Foswiki::Sandbox->sysCommand(
    $cmd,
    BLOCKSIZE => $blockSize,
    FILEPATH => $filePath,
  );

  #_writeDebug("output=$output");
  #_writeDebug("exit=$exit");
  #_writeDebug("error=$error");
  return _inlineError($error) if $exit;

  my @filesystems = ();
  foreach my $line (split(/\n/, $output)) {
    #Filesystem          1B-blocks           Used     Available Use% Mounted on
    #tmpfs              3270164        6588    3263576       1% /run
    next if $line =~ /^Filesystem/;
    if ($line =~ /^([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)$/) {
      push @filesystems, {
        device => $1,
        size => $human ? _humanizeBytes($2, $prec) : $2,
        used => $human ? _humanizeBytes($3, $prec) : $3,
        available => $human ? _humanizeBytes($4, $prec) : $4,
        percent => $5,
        mount => $6,
      }
    } else {
      _writeDebug("skipping line $line");
    }
  }

  return \@filesystems;
}

sub cpuLoad {
  my $this = shift;

  unless ($this->{_cpuLoad}) {
    my @load = Sys::CpuLoad::load();
    $this->{_cpuLoad} = {
      "1min" => $load[0],
      "5min" => $load[1],
      "15min" => $load[2],
    };
  }

  return $this->{_cpuLoad};
}

sub memInfo {
  my $this = shift;

  unless ($this->{_meminfo}) {
    $this->{_meminfo} = {};
    foreach my $key (Sys::MemInfo::availkeys()) {
      my $val = Sys::MemInfo::get($key);
      $this->{_meminfo}{$key} = $val;
    }
  }

  return $this->{_meminfo};
}

sub MEMINFO {
  my ($this, $session, $params, $topic, $web) = @_;

  return _inlineError("access denied") unless $this->allowed;

  _writeDebug("called MEMINFO()");
  my $result = $params->{format} // 'total=$totalmem, free=$freemem, swap=$totalswap, free=$freeswap';

  my $info = $this->memInfo();
  my $human = Foswiki::Func::isTrue($params->{human}, 0);
  my $prec = $params->{precision} // 2;

  while (my ($key, $val) = each %{$info}) {
    $val = _humanizeBytes($val, $prec) if $human;
    _writeDebug("key=$key, val=$val");
    $result =~ s/\$$key\b/$val/g;
  }

  return $result;
}

sub CPULOAD {
  my ($this, $session, $params, $topic, $web) = @_;

  return _inlineError("access denied") unless $this->allowed;
  _writeDebug("called CPULOAD()");

  my $result = $params->{format} // '1min=$1min, 5min=$5min, 15min=$15min';
  my $prec = $params->{precision} // 2;

  while (my ($key, $val) = each %{$this->cpuLoad}) {
    $val = sprintf("%.${prec}f", $val);
    $result =~ s/\$$key\b/$val/g;
  }

  return Foswiki::Func::decodeFormatTokens($result);
};

sub DISKFREE {
  my ($this, $session, $params, $topic, $web) = @_;

  return _inlineError("access denied") unless $this->allowed;

  _writeDebug("called DISKFREE()");

  my $header = $params->{header} // '';
  my $footer = $params->{footer} // '';
  my $separator = $params->{separator} // '';
  my $format = $params->{format} // 'device=$device, size=$size, used=$used, available=$available, percent=$percent';
  my $include = $params->{include};
  my $exclude = $params->{exclude};

  my $res = $this->df($params);
  #_writeDebug("df=".dump($res));

  my @result = ();
  foreach my $record (@$res) {
    next if $include && $record->{device} !~ /$include/ && $record->{mount} !~ /$include/;
    next if $exclude && ($record->{device} =~ /$exclude/ || $record->{mount} =~ /$exclude/);

    my $line = $format;
    while (my ($key, $val) = each %$record) {
      $line =~ s/\$$key\b/$val/g;
    }

    push @result, $line if $line ne "";
  }

  return "" unless @result;
  return Foswiki::Func::decodeFormatTokens($header.join($separator, @result).$footer);
}

sub _writeDebug {
  return unless TRACE;
  print STDERR "SysinfoPlugin::Core - $_[0]\n";
}

sub _inlineError {
  my $msg = shift;
  $msg =~ s/ at .*$//m;

  return "<span class='foswikiAlert'>$msg</span>";
}

our @BYTE_SUFFIX = ('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB');
sub _humanizeBytes {
  my ($bytes, $prec, $max) = @_;

  $max ||= '';
  $prec //= 2;

  my $magnitude = 0;
  my $suffix;
  while ($magnitude < scalar(@BYTE_SUFFIX)) {
    $suffix = $BYTE_SUFFIX[$magnitude];
    last if $bytes < 1024;
    last if $max eq $suffix;
    $bytes /= 1024;
    $magnitude++;
  };

  my $result = sprintf("%.0${prec}f", $bytes);
  $result =~ s/\.00$//;
  $result .= " " . $suffix;

  return $result;
}

1;
