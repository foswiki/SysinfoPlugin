# Plugin for Foswiki - The Free and Open Source Wiki, https://foswiki.org/
#
# SysinfoPlugin is Copyright (C) 2026 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::SysinfoPlugin;

=begin TML

---+ package Foswiki::Plugins::SysinfoPlugin

plugin class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '0.01';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'detailed operating system information';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler('MEMINFO', sub { return getCore()->MEMINFO(@_); });
  Foswiki::Func::registerTagHandler('CPULOAD', sub { return getCore()->CPULOAD(@_); });
  Foswiki::Func::registerTagHandler('DISKFREE', sub { return getCore()->DISKFREE(@_); });

  return 1;
}

=begin TML

---++ finishPlugin

finish the plugin and the core if it has been used,
automatically called during the core initialization process

=cut

sub finishPlugin {
  $core->finish() if $core;
  undef $core;
}

=begin TML

---++ getCore() -> $core

returns a singleton core object for this plugin

=cut

sub getCore {
  unless (defined $core) {
    require Foswiki::Plugins::SysinfoPlugin::Core;
    $core = Foswiki::Plugins::SysinfoPlugin::Core->new();
  }
  return $core;
}

1;
