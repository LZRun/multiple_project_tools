#!/usr/bin/env ruby
# encoding: UTF-8

require 'colored2'
require 'json'
require_relative 'LocalizationPlatform.rb'

module Pixab

  class Localization

    ACCESS_TOKEN = '4f5379d0d26b9a2ef167b3fc84fb47f1fe2b4e87b1f95d8f5fc15269132051ef'

    attr_accessor :projects, :tags, :platform, :mode

    def initialize()
      @platform = 'iOS'
    end

    def run(commands = nil)
      commands.each_index do |index|
        command = commands[index]
        case command
        when "--projects"
          @projects = commands[index + 1]
        when "--tags" 
          @tags = commands[index + 1]
        when "--platform"
          @platform = commands[index + 1]
        when "--mode"
          @mode = commands[index + 1]
        end
      end

      puts "\n》》》》》正在下载本地化文案 》》》》》》》》》》\n".green
      localized_info_category = retrieveLocalizationString

      puts "\n》》》》》正在替换本地化文案 》》》》》》》》》》\n".green
      replace_local_files(localized_info_category)
    end

    # 从Phrase平台检索获取本地化文案
    def retrieveLocalizationString
      if projects.nil?
        puts "Error: project id cannot be nil".red
        exit(1)
      end

      localized_info_category = {}
      project_array = projects.split(',')
      project_array.each do |project|
        command = "\"https://api.phrase.com/v2/projects/#{project}/translations" 
        if !tags.nil?
          command += "?q=tags:#{tags}"
        end
        command += "\" -u #{ACCESS_TOKEN}:"
        localized_string = `curl #{command}`
        localized_info_category.merge!(assemble_data(localized_string)) do |key, oldval, newval|
          oldval + newval
        end
      end
      return localized_info_category
    end

    # 重新组装本地化数据
    def assemble_data(string)
      objects = JSON.parse(string)
      localized_info_category = {}
      objects.each do |object|
        locale_name = object["locale"]["name"]
        localized_infos = localized_info_category[locale_name]
        if localized_infos.nil?
          localized_infos = []
          localized_info_category[locale_name] = localized_infos
        end
        localized_infos.push({'key' => "#{object['key']['name']}", 'value' => "#{object['content']}"})
      end
      return localized_info_category
    end

    # 替换本地文件
    def replace_local_files(localized_info_category)
      platform_commands = nil
      if !mode.nil? 
        platform_commands = ['--mode', mode]
      end
      if platform == 'android'
        LocalizationAndroid.new.run(localized_info_category, platform_commands)
      else
        LocalizationiOS.new.run(localized_info_category, platform_commands)
      end
    end
    
  end

end

Pixab::Localization.new.run(ARGV)

