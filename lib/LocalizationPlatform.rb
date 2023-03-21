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
      if commands.nil?
        return
      end
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

      begin_prompt = "\n// Created from phrase api <<<<<<<<<< begin\n"
      end_prompt = "\n// Created from phrase api <<<<<<<<<< end\n"

      localized_info_category.each do |locale, localized_infos|
        content_dir_path = dir_name(locale)
        if !Dir.exists?(content_dir_path)
          FileUtils.mkdir_p content_dir_path
        end
        content_file_path = "#{content_dir_path}/#{File_name}"
        if @file_mode == 'a+' and File::exists?(content_file_path)
          # 移除以前脚本添加的本地化文案
          content = File.read(content_file_path)
          content = content.sub(/#{begin_prompt}.*#{end_prompt}/m, '')
          File.open(content_file_path, 'w+') do |file|
            file.syswrite(content)
          end
        end
        File.open(content_file_path, @file_mode) do |file|
          file.syswrite(begin_prompt)
          localized_infos.each do |localized_info|
            file.syswrite("\n\"#{localized_info['key']}\" = \"#{localized_info['value']}\";\n")
          end
          file.syswrite(end_prompt)
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
        File.open(content_file_path, @file_mode) do |file|
          file.syswrite("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
          file.syswrite("<resources>\n")
          localized_infos.each do |localized_info|
            value = localized_info['value'].gsub(/['"]/, '\\\\\0')
            file.syswrite("  <string name=\"#{localized_info['key']}\">#{value}</string>\n")
          end
          file.syswrite("</resources>\n")
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