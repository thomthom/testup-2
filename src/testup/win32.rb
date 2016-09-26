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
    
    extern 'DWORD GetCurrentThreadId()'
  end


  # http://msdn.microsoft.com/en-us/library/ms633502%28v=vs.85%29.aspx
  GA_PARENT     = 1
  GA_ROOT       = 2
  GA_ROOTOWNER  = 3
  module User32
    extend Fiddle::Importer
    dlload 'user32.dll'
    include Fiddle::Win32Types

    extern 'HWND GetAncestor(HWND, UINT)'

    #extern 'BOOL EnumThreadWindows(DWORD, WNDENUMPROC, LPARAM)'
    extern 'BOOL EnumThreadWindows(DWORD, PVOID, PVOID)'

    extern 'HWND SetFocus(HWND)'
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

  # Module to aid in calling shortcuts known to SketchUp under Windows.
  #
=begin
    Sketchup.get_shortcuts.each { |line|
      shortcut, path = line.split("\t")
      puts "#{TestUp::Win32Helper::Shortcuts.transpose_keys(shortcut)}\t#{line}"
    }
    nil
=end
  module Shortcuts

    # Trigger a given shortcut command.
    #
    # TestUp::Win32Helper::Shortcuts.trigger('Edit/Item/Edit Component')
    # TestUp::Win32Helper::Shortcuts.trigger('Edit/Item/Edit Group')
    #
    # @param [String] command_path
    # @return [Boolean]
    def self.trigger(command_path)
      shortcut = self.get_shortcut(command_path)
      return false if shortcut.nil?
      # Ensure SketchUp's main window have the focus so it receives the
      # shortcut key strokes.
      hwnd = TestUp::Win32Helper.get_main_window_handle
      TestUp::Win32Helper::User32.SetFocus(hwnd)
      # Prepare the shortcut sequence for SendKeys.
      keys = self.transpose_keys(shortcut)
      self.send_keys(keys)
      true
    end

    # Return the shortcut combination for a given command.
    #
    # TestUp::Win32Helper::Shortcuts.get_shortcut('Edit/Item/Edit Component')
    # TestUp::Win32Helper::Shortcuts.get_shortcut('Edit/Item/Edit Group')
    #
    # @param [String] command_path
    # @return [String]
    def self.get_shortcut(command_path)
      Sketchup.get_shortcuts.each { |data|
        shortcut, command = data.split("\t")
        return shortcut if command == command_path
      }
      nil
    end

    # Converts a shortcut string from self.get_shortcut to a string that can be
    # used by self.send_keys.
    #
    # @param [String] shortcut
    # @return [String]
    #
    # https://msdn.microsoft.com/en-us/library/8c6yea83(v=vs.84).aspx
    # http://ss64.com/vb/sendkeys.html
    def self.transpose_keys(shortcut)
      # TODO(thomthom): Not all key combinations are mapped. Need to figure out
      # the variations SketchUp use for special keys.
      keys = shortcut.split('+')
      keys.map { |key|
        key
          .gsub('Ctrl',      '^')
          .gsub('Shift',     '+')
          .gsub('Alt',       '%')
          .gsub('Backspace', '{BACKSPACE}')
          .gsub('Delete',    '{DELETE}')
          .gsub('Insert',    '{INSERT}')
          .gsub('Space',     '{SPACE}')
          .gsub('PageDown',  '{PGDN}')
          .gsub('PageUp',    '{PGUP}')
          .gsub(/(F\d+)/,    '{\1}')
      }.join
    end
    
    # Triggers a wscript that will simulate a set of key strokes.
    #
    # @param [String] keys
    def self.send_keys(keys)
      sendkeys_vbs = File.join(__dir__, 'sendkeys.vbs')
      `wscript "#{sendkeys_vbs}" "#{keys}"`
    end

  end # module


 end # module Win32Helper
end # module TestUp
