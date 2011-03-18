# -*- coding: utf-8 -*-
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

    @clips = Clippings.new(File.open(clipfile).read, debug)

    @filters = {:notes => @glade['ck_show_notes'].active?,
      :bookmarks => @glade['ck_show_notes'].active?,
      :highlights => @glade['ck_show_highlights'].active?,
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
    set_status 'One day we will do filter_entry_activate'
  end

  def on_quit_button_clicked(button)
    Gtk.main_quit
  end

  def on_filter_button_clicked(button)
    set_status 'One day we will do filter_button'
  end

  def on_revert_button_clicked(button)
    [:bookmarks, :highlights, :notes].each do |kind|
      @glade['ck_show_%s' % kind].active = true
      @filters[kind] = true
    end

    # We should also reset the selector on @glade['books_treeview'] -
    # Right now, this only gets the same effect by clearing the filter
    @glade['books_treeview'].selection.unselect_all
    @filters[:book] = nil

    refresh_listing
  end

  def on_clipping_file_select_button_clicked(button)
    set_status 'One day we will do clipping_file_select'
  end

  def on_books_treeview_cursor_changed(view)
    # Later: Allow for multiple book selection
    filters[:book] = view.selection.selected[0]
    refresh_listing
  end

  def on_clippings_treeview_cursor_changed(view)
    row = view.selection.selected
    @glade['clip_text'].text = "Book: %s\n%s\n\n%s" % [row[0], row[1], row[4]]
  end

  ############################################################
  # 
  private

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
    @models[:clip] = setup_list(%w(Book Type Timestamp Text Full), treeview)
    treeview.get_column(4).visible = false
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

    list.each do |clip|
      if clip.text.size > 100
        short_text = clip.text[0..98]+'(…)'
      else
        short_text = clip.text
      end

      iter = @models[:clip].append
      iter[0] = clip.book
      iter[1] = clip.kind
      iter[2] = clip.timestamp.strftime('%Y-%m-%d %H:%M')
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
