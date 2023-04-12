#!/usr/bin/env ruby
# encoding: UTF-8

require 'colored2'
require 'json'
require_relative 'LocalizationPlatform.rb'

module Pixab

  class Localization

    ACCESS_TOKEN = 'bdbda2cc022951235808a4f6c7a7330d4de7dcf719650d7d2ceee260e07d3f01'
    Project_AirBrush = '546ed49bfca9d3a4f51ccf2c8c279d0f'
    Project_AirBrush_Video = 'fcb3e858aa1d991e8c21222f3696ce67'

    attr_accessor :projects, :tags, :platform, :mode

    def initialize()
      @platform = 'iOS'
    end

    def run(commands = nil)
      commands.each_index do |index|
        command = commands[index]
        case command
        when '--project-ab'
          add_project(Project_AirBrush)
        when '--project-abv'
          add_project(Project_AirBrush_Video)
        when '--ab-android'
          @projects = "#{Project_AirBrush},#{Project_AirBrush_Video}"
          @platform = 'android'
          @tags = 'android'
        when '--ab-iOS'
          @projects = "#{Project_AirBrush}"
          @mode = 'add'
          @tags = 'iOS'
        when '--abv-iOS'
          @projects = "#{Project_AirBrush_Video}"
          @mode = 'add'
          @tags = 'iOS'
        end
      end

      commands.each_index do |index|
        command = commands[index]
        case command
        when '--projects'
          @projects = commands[index + 1] 
        when '--tags' 
          @tags = commands[index + 1]
        when '--platform'
          @platform = commands[index + 1]
        when '--mode'
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
        page_number = 1
        while true
          link = "\"https://api.phrase.com/v2/projects/#{project}/translations?page=#{page_number}&per_page=100&sort=created_at" 
          if !tags.nil?
            link += "&q=tags:#{tags}%20excluded:false" 
          end
          link += "\""
          access_token = "-u #{ACCESS_TOKEN}:"
          localized_string = `curl #{link} #{access_token}`
          per_localized_info_category = assemble_data(localized_string)
          if per_localized_info_category.empty?
            break
          end
          localized_info_category.merge!(per_localized_info_category) do |key, oldval, newval|
            oldval + newval
          end
          page_number += 1
        end
      end
      return localized_info_category
    end

    # 重新组装本地化数据
    def assemble_data(string)
      if string.nil? || string.empty?
        return {}
      end

      localized_info_category = {}
      objects = JSON.parse(string)
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
    
    # 添加拉取的project
    def add_project(project_id)
      if projects.nil?
        @projects = "#{project_id}"
      else
        @projects += ",#{project_id}"
      end
    end

  end

end

