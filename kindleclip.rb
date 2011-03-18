#!/usr/bin/ruby
require 'clippings'
require 'kindleclip/ui'

clipfile = $ARGV[0] || 'My Clippings.txt'

if ! File.exists?(clipfile)
  puts '"My Clippings.txt" was not found in the current path, and no clippings'
  puts 'file was otherwise specified - Cannot continue.'
  exit 1
end

ui = KindleClipUI.new(clipfile)
ui.show
Gtk.main
