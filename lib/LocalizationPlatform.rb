#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"
require_relative './Utilities.rb'

module Pixab

  class LocalizationPlatform

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
          @mode = commands[index + 1]
        end
      end
    end

    def dir_name(locale)
      return ''
    end 

    def file_mode
      case @mode
      when 'add'
        return 'a+'
      else 
        return 'w+'
      end
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
        if !Utilities.dir_exist(content_dir_path)
          FileUtils.mkdir_p content_dir_path
        end
        content_file_path = "#{content_dir_path}/#{File_name}"
        
        case @mode
        when 'add'
          write_file_add(content_file_path, localized_infos)
        when 'replace'
          write_file_replace(content_file_path, localized_infos)
        when 'append'
          write_file_append(content_file_path, localized_infos)
        else 
          write_file_by_mode(content_file_path, localized_infos, 'w')
        end
      end
    end

    def dir_name(locale)
      "#{locale}.lproj"
    end

    def write_file_add(content_file_path, localized_infos)
      if File::exists?(content_file_path)
        # 移除以前脚本添加的本地化文案
        content = File.read(content_file_path)
        content = content.sub(/#{begin_prompt}.*#{end_prompt}/m, '')
        File.open(content_file_path, 'w+') do |file|
          file.syswrite(content)
        end
      end
      write_file_by_mode(content_file_path, localized_infos, file_mode)
    end

    def write_file_replace(content_file_path, localized_infos)
      # write_file_by_mode(content_file_path, localized_infos, file_mode)
    end

    def write_file_append(content_file_path, localized_infos)
      if File::exists?(content_file_path)
        file_content = File.read(content_file_path)
        if index = file_content.index(end_prompt)
          localized_infos.each do |localized_info|
            file_content.insert(index, genetate_localized_string(localized_info))        
          end
          File.open(content_file_path, 'w') { |file| file.write(file_content) }
          return
        end
      end
      write_file_by_mode(content_file_path, localized_infos, 'a+')
    end

    def write_file_by_mode(content_file_path, localized_infos, mode)
      File.open(content_file_path, mode) do |file|
        file.syswrite(begin_prompt)
        localized_infos.each do |localized_info|
          file.syswrite(genetate_localized_string(localized_info))
        end
        file.syswrite(end_prompt)
      end
    end

    def begin_prompt
      return "\n// Created from phrase api <<<<<<<<<< begin\n"
    end

    def end_prompt
      return "\n// Created from phrase api <<<<<<<<<< end\n"
    end

    def genetate_localized_string(localized_info)
      value = localized_info['value'].gsub(/["]/, '\\\\\0')
      value = value.gsub(/%s/, '%@')
      return "\n\"#{localized_info['key']}\" = \"#{value}\";\n"
    end

  end

end

module Pixab

  class LocalizationMac < LocalizationiOS

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
        if !Utilities.dir_exist(content_dir_path)
          FileUtils.mkdir_p content_dir_path
        end
        content_file_path = "#{content_dir_path}/#{File_name}"
        File.open(content_file_path, file_mode) do |file|
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