#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'date'

class Clippings < Array
  def initialize(text, debug=0)
    @debug = debug
    @raw = text
    @raw.split(/[\r\n]+==========[\r\n]+/).each do |item|
      self << ClipItem.new(item, @debug)
    end
  end

  def filter_by(field, value)
    select {|i| i.send(field) == value}
  end

  def books
    self.map{|clip| clip.book}.uniq
  end
end

class ClipItem
  ItemTypes = %w(Note Bookmark Highlight)
  class InvalidStructure < ArgumentError; end

  attr_accessor :book, :kind, :place, :timestamp, :text
  # Each of the clippings' items follows the following format:
  #
  #   Cain (Jose Saramago)
  #   - Highlight Loc. 92-94  | Added on Monday, January 11, 2010, 06:07 PM
  #
  #   Quién ha desobedecido mis órdenes, quién se ha acercado al fruto de mi árbol, preguntó dios, dirigiéndole directamente a adán una mirada coruscante, palabra desusada pero expresiva como la que más.
  #
  # This means:
  #
  # - Line 1: <Book name>
  # - Line 2: - <item type> <place>  | Added on <timestamp>
  # - Line 3: (Blank)
  # - Line 4 to end of record: Text
  def initialize(text, debug=0)
    @debug = debug.is_a?(Fixnum) ? debug : 0

    debug 4, '=' * 10
    debug 5, "Processing\n:\n%s" % text

    lines = text.split(/\r?\n/)
    read_title(lines.shift)
    read_kind_place_tstamp(lines.shift)
    ck_blank(lines.shift)
    read_text(lines.join("\n"))
  end

  private
  def debug(level, data)
    return true if !(@debug.is_a? Fixnum) or level > @debug
    puts '%5s %s' % ['*' * level, data]
  end

  def read_title(str)
    @book = str
    debug 4, 'Book title: "%s"' % @book
  end

  def read_kind_place_tstamp(str)
    debug 4, 'Parsing: "%s"' % str
    str =~ /^- (\w+) (.+) +\| Added on (.+)/ or
      raise InvalidStructure, 'Cannot parse "%s"' % str
    @kind, @place, tstamp = $1, $2, $3
    raise InvalidStructure, ('Unknown item type: "%s"' % @kind) unless
      ItemTypes.include?(@kind)
    @timestamp = DateTime.parse(tstamp) or
      raise InvalidStructure, 'Cannot parse timestamp: "%s"' % tstamp
    debug 4, 'Item type: "%s"; Place: "%s"; Timestamp: %s' %
      [@kind, @place, @timestamp]

  end

  def ck_blank(str)
    debug 4, 'Checking blanks: "%s"' % str
    raise InvalidStructure, 'Blank line expected - Got "%s"' % str if str=~/\w/
  end

  def read_text(str)
    debug 4, 'Reading text: "%s"' % str
    @text = str
  end
end
