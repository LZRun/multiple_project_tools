#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"

module Pixab

  class LocalizationPlatform

    def initialize()
      @file_mode = 'w+'
    end

    def run(localized_info_category, commands)
      resolve_commands(commands)
    end

    def resolve_commands(commands)
      if !commands.nil?
        commands.each_index do |index|
          command = commands[index]
          case command
          when "--mode"
            mode = commands[index + 1]
            if mode == 'add'
              @file_mode = 'a+'
            end
          end
        end
      end
    end

    def dir_name(locale)
      return ''
    end 

  end

end


module Pixab

  class LocalizationiOS < LocalizationPlatform

    File_name = "Localizable.strings"

    def run(localized_info_category, commands)
      super(localized_info_category, commands)

      localized_info_category.each do |locale, localized_infos|
        content_dir_path = dir_name(locale)
        if !Dir.exists?(content_dir_path)
          FileUtils.mkdir_p content_dir_path
        end
        content_file_path = "#{content_dir_path}/#{File_name}"
        File.open(content_file_path, @file_mode) do |aFile|
          aFile.syswrite("\n// Created from phrase api <<<<<<<<<< begin\n")
          localized_infos.each do |localized_info|
            aFile.syswrite("\n\"#{localized_info['key']}\" = \"#{localized_info['value']}\";\n")
          end
          aFile.syswrite("\n// Created from phrase api <<<<<<<<<< end\n")
        end
      end
    end


    def dir_name(locale)
      "#{locale}.lproj"
    end


  end

end

module Pixab

  class LocalizationAndroid < LocalizationPlatform

    File_name = "strings_ph.xml"
    Exclude_locales = ['zh-Hant']

    def run(localized_info_category, commands)
      localized_info_category.each do |locale, localized_infos|
        if Exclude_locales.include?(locale)
          next
        end

        content_dir_path = dir_name(locale)
        if !Dir.exists?(content_dir_path)
          FileUtils.mkdir_p content_dir_path
        end
        content_file_path = "#{content_dir_path}/#{File_name}"
        File.open(content_file_path, @file_mode) do |aFile|
          aFile.syswrite("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
          aFile.syswrite("<resources>\n")
          localized_infos.each do |localized_info|
            aFile.syswrite("  <string name=\"#{localized_info['key']}\">#{localized_info['value']}</string>\n")
          end
          aFile.syswrite("</resources>\n")
        end
      end
    end


    def dir_name(locale)
      suffix = ''
      case locale
      when 'en'
        suffix = ''
      when 'fr'
        suffix = '-fr-rFR'
      when 'ru'
        suffix = '-ru-rRU'
      when 'zh-Hans'
        suffix = '-zh-rCN'
      when 'tr'
        suffix = '-tr-rTR'
      else
        suffix = "-#{locale}"
      end
      return "values#{suffix}"
    end

  end

end