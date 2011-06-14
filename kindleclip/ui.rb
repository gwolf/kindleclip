# -*- coding: utf-8 -*-
#
# KindleClip/UI
# =============
#
# User interface for managing Amazon Kindle's "My Clippings"
# file. This file implements the UI bindings with Glade.
#
# Copyright © 2011 Gunnar Wolf <gwolf@gwolf.org>
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
require 'libglade2'
require 'gettext'
require 'clippings'

class KindleClipUI
  include GetText
  bindtextdomain('kindleclip', ENV['GETTEXT_PATH'])
  attr_accessor :glade, :clips, :models, :filters

  def initialize(clipfile, domain='kindleclip', localedir='locale')
    bindtextdomain(domain, localedir)
    debug = 0

    @glade = Gtk::Builder.new
    @glade.add_from_file('kindleclip/kindleclip.glade')
    @glade.connect_signals {|handler| method(handler) }

    read_clippings(clipfile)

    @filters = {:notes => @glade['ck_show_notes'].active?,
      :bookmarks => @glade['ck_show_bookmarks'].active?,
      :highlights => @glade['ck_show_highlights'].active?,
      :text => nil,
      :book => nil}
    @models = {}

    setup_book_list(@glade['books_treeview'])
    setup_clippings_list(@glade['clippings_treeview'])

    refresh_listing
  end

  def show
    window = @glade['window1']
    window.show_all
    window.signal_connect('destroy') {Gtk.main_quit}
  end

  def show_about_window
    about = @glade['aboutdialog1']
    about.version = version
    about.run
    about.hide
  end

  ############################################################
  # Callbacks
  def on_ck_show_notes_toggled(ckbox)
    show = ckbox.active?
    @filters[:notes] = show
    refresh_listing
  end

  def on_ck_show_bookmarks_toggled(ckbox)
    show = ckbox.active?
    @filters[:bookmarks] = show
    refresh_listing
  end

  def on_ck_show_highlights_toggled(ckbox)
    show = ckbox.active?
    @filters[:highlights] = show
    refresh_listing
  end

  def on_text_filter_entry_activate(entry)
    set_text_filter
  end

  def on_quit_button_clicked(button)
    Gtk.main_quit
  end

  def on_filter_button_clicked(button)
    set_text_filter
  end

  def on_about_button_clicked(button)
    show_about_window
  end

  def on_revert_button_clicked(button)
    @glade['ck_show_bookmarks'].active = false
    @filters[:bookmarks] = false
    @glade['ck_show_highlights'].active = true
    @filters[:highlights] = true
    @glade['ck_show_notes'].active = true
    @filters[:notes] = true

    # We should also reset the selector on @glade['books_treeview'] -
    # Right now, this only gets the same effect by clearing the filter
    @glade['books_treeview'].selection.unselect_all
    @filters[:book] = nil

    refresh_listing
  end

  def on_clipping_file_select_button_clicked(button)
    chooser = @glade['filechooser']
    chooser.run
    chooser.hide
  end

  def on_filechooser_file_activated(chooser)
    chooser.hide
    file = chooser.filename
    read_clippings(file)
    refresh_listing
  end

  def on_books_treeview_cursor_changed(view)
    # Later: Allow for multiple book selection
    if view.selection.selected
      filters[:book] = view.selection.selected[0] 
    else
      filters[:book] = nil
    end
    refresh_listing
  end

  def on_clippings_treeview_cursor_changed(view)
    row = view.selection.selected
    if row
      @glade['clip_text'].buffer.text = "Book: %s\n%s\n\n%s" % [row[0], row[1], row[4]]
    else
      @glade['clip_text'].buffer.text = ''
    end
  end

  ############################################################
  # 
  private
  def version
    ::KindleClipVersion
  end

  def read_clippings(file)
    begin
      @clips = Clippings.new(File.open(file).read)
    rescue ClipItem::InvalidStructure
      error = @glade['clipping_format_error_dialog']
      error.run
      error.hide
      @clips = Clippings.new('')
    end
  end

  def set_text_filter
    text = @glade['text_filter_entry'].text
    text = nil if text.empty?
    @filters[:text] = text
    refresh_listing
  end

  # Sets the status bar message
  def set_status(text, ctx='status_msg')
    status = @glade['status']
    context = status.get_context_id(ctx)
    status.pop(context)
    status.push(context, text)
  end

  def setup_book_list(treeview)
    @models[:book] = setup_list(%w(Book), treeview)
    @clips.books.sort.each do |book| 
      iter = @models[:book].append
      iter[0] = book
    end
  end

  def setup_clippings_list(treeview)
    @models[:clip] = setup_list(%w(Type Timestamp Book Text Full), treeview)
    treeview.get_column(0).max_width = 200 # Type
    treeview.get_column(1).max_width = 200 # Timestamp
    treeview.get_column(2).max_width = 500 # Book
    treeview.get_column(3).max_width = 500 # Text
    treeview.get_column(4).visible = false # Full
  end

  # We specify the listing criteria via @filters
  def refresh_listing
    @models[:clip].clear

    list = @clips
    if @filters[:book]
      list = list.select {|cl| cl.book == @filters[:book]}
    end

    list = list.reject {|l| l.kind == 'Bookmark'} if !@filters[:bookmarks]
    list = list.reject {|l| l.kind == 'Highlight'} if !@filters[:highlights]
    list = list.reject {|l| l.kind == 'Note'} if !@filters[:notes]

    if has_text = @filters[:text]
      list = list.select {|l| l.text.index(has_text)}
    end

    list.each do |clip|
      if clip.text.size > 100
        short_text = clip.text[0..98]+'(…)'
      else
        short_text = clip.text
      end

      iter = @models[:clip].append
      iter[0] = clip.kind
      iter[1] = clip.timestamp.strftime('%Y-%m-%d %H:%M')
      iter[2] = clip.book
      iter[3] = short_text.gsub(/\n/,' ')
      iter[4] = clip.text
    end


    set_status('Showing %d clippings' % list.size)
  end

  def setup_list(columns, treeview)
    model = Gtk::ListStore.new(*columns.map{String})
    treeview.model = model

    colnum = 0
    columns.each do |colhead|
      col = Gtk::TreeViewColumn.new(colhead, 
                                    Gtk::CellRendererText.new,
                                    'text' => colnum)
      col.clickable = true
      col.resizable = true
      col.sort_column_id = colnum
      treeview.append_column(col)
      colnum += 1
    end

    treeview.enable_search = true
    treeview.search_column = 2

    model
  end
end
