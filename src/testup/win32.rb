#-------------------------------------------------------------------------------
#
# Copyright 2013-2016 Trimble Navigation Ltd.
# License: The MIT License (MIT)
#
#-------------------------------------------------------------------------------


require 'fiddle'
require 'fiddle/types'
require 'fiddle/import'


module TestUp
 module Win32Helper

  include Fiddle

  FALSE = 0
  TRUE  = 1


  module Kernel32
    extend Fiddle::Importer
    dlload 'kernel32.dll'
    include Fiddle::Win32Types

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms683183(v=vs.85).aspx
    extern 'DWORD GetCurrentThreadId()'
  end


  # http://msdn.microsoft.com/en-us/library/ms633502%28v=vs.85%29.aspx
  GA_PARENT     = 1
  GA_ROOT       = 2
  GA_ROOTOWNER  = 3

  MF_BYCOMMAND  = 0x00000000
  MF_BYPOSITION = 0x00000400

  # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647591(v=vs.85).aspx
  WM_COMMAND = 0x0111

  module User32
    extend Fiddle::Importer
    dlload 'user32.dll'
    include Fiddle::Win32Types

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms633502(v=vs.85).aspx
    extern 'HWND GetAncestor(HWND, UINT)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms633495(v=vs.85).aspx
    #extern 'BOOL EnumThreadWindows(DWORD, WNDENUMPROC, LPARAM)'
    extern 'BOOL EnumThreadWindows(DWORD, PVOID, PVOID)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647640(v=vs.85).aspx
    # typedef HANDLE HMENU;
    #extern 'HMENU GetMenu(HWND)'
    extern 'HANDLE GetMenu(HWND)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647984(v=vs.85).aspx
    #extern 'HMENU GetSubMenu(HMENU, int)'
    extern 'HANDLE GetSubMenu(HANDLE, int)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647978(v=vs.85).aspx
    #extern 'int GetMenuItemCount(HMENU)'
    extern 'int GetMenuItemCount(HANDLE)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647979(v=vs.85).aspx
    # The return value is the identifier of the specified menu item. If the menu
    # item identifier is NULL or if the specified item opens a submenu, the
    # return value is -1.
    #extern 'int GetMenuItemID(HMENU, int)'
    extern 'int GetMenuItemID(HANDLE, int)'

    
    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms647983(v=vs.85).aspx
    #extern 'int GetMenuString(HMENU, UINT, LPTSTR, int, UINT)'
    extern 'int GetMenuString(HANDLE, UINT, PVOID, int, UINT)'

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms644944(v=vs.85).aspx
    # typedef UINT_PTR WPARAM;
    # typedef LONG_PTR LPARAM;
    #extern 'BOOL PostMessage(HWND, UINT, WPARAM, LPARAM)'
    extern 'BOOL PostMessage(HANDLE, UINT, PVOID, PVOID)'
  end


  # TestUp::Win32Helper.get_main_window_handle
  #
  # Returns the window handle of the SketchUp window for the input queue of the
  # calling ruby method.
  #
  # @return [Integer] Returns a window handle on success or +nil+ on failure
  def self.get_main_window_handle
    thread_id = Kernel32.GetCurrentThreadId()
    main_hwnd = 0
    param = 0

    enumWindowsProc = Closure::BlockCaller.new(TYPE_INT,
      [TYPE_VOIDP, TYPE_VOIDP]) { |hwnd, lparam|
        main_hwnd = User32.GetAncestor(hwnd, GA_ROOTOWNER)
        next FALSE
    }

    User32.EnumThreadWindows(thread_id, enumWindowsProc, param)
    main_hwnd
  end


  class Menu

    include Enumerable
    include Fiddle

    def self.get
      hwnd = Win32Helper.get_main_window_handle
      hmenu = User32.GetMenu(hwnd)
      self.new(hmenu)
    end

    attr_reader :hmenu, :index

    def initialize(hmenu, index = nil)
      @hmenu = hmenu
      @index = index
      if index.nil?
        @num_items = User32.GetMenuItemCount(hmenu)
      else
        sub_hmenu = User32.GetSubMenu(hmenu, index)
        @num_items = (sub_hmenu == NULL) ? 0 : User32.GetMenuItemCount(sub_hmenu)
      end
    end

    def trigger
      return nil if @index.nil?
      hwnd = Win32Helper.get_main_window_handle
      menu_id = User32.GetMenuItemID(@hmenu, @index)
      low_word = menu_id
      high_word = 0
      w_param = (high_word << 16) | low_word
      l_param = 0
      User32.PostMessage(hwnd, WM_COMMAND, w_param, l_param)
    end

    def each
      @num_items.times { |index|
        yield self.class.new(@hmenu, index)
      }
    end

    def last
      return nil if @num_items < 1
      self.class.new(@hmenu, @num_items - 1)
    end

    def title
      get_title
    end

    def label
      title.tr('&', '')
    end

    def size
      @num_items
    end

    def sub_menu?
      @num_items > 0
    end

    def sub_menu
      sub_hmenu = User32.GetSubMenu(@hmenu, @index)
      return nil if sub_hmenu == NULL
      self.class.new(sub_hmenu)
    end

    private

    def get_title
      return nil if @index.nil?
      buffer_size = User32::GetMenuString(@hmenu, @index, NULL, 0, MF_BYPOSITION)
      buffer_size += 1
      buffer = "\u0000" * buffer_size
      result = User32::GetMenuString(@hmenu, @index, buffer, buffer_size, MF_BYPOSITION)
      buffer.strip
    end

  end # class

 end # module Win32Helper
end # module TestUp
