# -*- coding: utf-8 -*-
#
# Clippings
# =========
#
# User interface for managing Amazon Kindle's "My Clippings"
# file. This file implements the "My Clippings.txt" parsing logic.
#
# Copyright © 2011-2014 Gunnar Wolf <gwolf@gwolf.org>
#
# ============================================================
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# ============================================================
#
# This program is in no way endorsed, promoted or should be associated
# with Amazon. It is not –and does not aim to be– an official Kindle
# project.
require 'date'

class Clippings < Array
  def initialize(text, debug=0)
    @debug = debug
    @raw = ck_encoding(text)
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

  private
  def ck_encoding(str)
    return str if str.valid_encoding?
    str.lines.map do |lin|
      lin.valid_encoding? ? lin :
        lin.chars.select{|c| c.valid_encoding?}
    end.join
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
    @place.gsub!(/(?:on )?(:?Page|Loc\.)/, '')
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
