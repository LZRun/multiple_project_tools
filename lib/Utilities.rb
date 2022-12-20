#!/usr/bin/env ruby
# encoding: UTF-8

require 'colored2'

module Pixab

  class Utilities

  end
  
  class << Utilities
  
    def check_shell_result(error_msg = nil, success = nil)
      is_success = success.nil? ? $?.to_i == 0 : success 
      if is_success 
        return
      end
      if !error_msg.nil?
        puts error_msg.red
      end
      exit(1)
    end
    
    def display_default_dialog(default_text)
      input_msg = `osascript -e 'display dialog "#{default_text}"'`.chomp
      reg = /button returned:(.+)/
      input_msg.match(reg)
      !$1.nil?
    end
    
    def display_dialog(default_text, default_answer = "")
      input_msg = `osascript -e 'display dialog "#{default_text}" default answer "#{default_answer}"'`.chomp
      reg = /text returned:(.+)/
      input_msg.match(reg)
      $1.nil? ? "" : $1
    end
  
    def display_choose_list(items, default_items = nil, title = nil, prompt = nil, ok_button_name = nil, cancel_button_name = nil, is_multiple_selections = false)
     shell = "osascript -e 'choose from list #{items}"
     if !title.nil?
      shell += " with title \"#{title}\""
     end
     if !prompt.nil?
      shell += " with prompt \"#{prompt}\""
     end
     if !ok_button_name.nil?
      shell += " OK button name \"#{ok_button_name}\""
     end
     if !cancel_button_name.nil?
      shell += " cancel button name \"#{cancel_button_name}\""
     end
     if !default_items.nil?
      shell += " default items #{default_items}"
     end
     if is_multiple_selections
      shell += " with multiple selections allowed"
     end
     shell += "'"
     selected_item_string = `#{shell}`.chomp
     if selected_item_string == "false"
      return []
     else 
      return selected_item_string.split(",")
     end
    end
  
  end
  
end