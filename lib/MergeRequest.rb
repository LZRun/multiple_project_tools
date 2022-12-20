#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"
require 'colored2'
require_relative './Utilities.rb'
require_relative './RepoManager.rb'

module Pixab
  
  class MergeRequest

    attr_accessor :repo_type, :default_commit_msg
    attr_reader :repo_manager, :repos, :command_options
  
    def initialize(repo_manager = RepoManager.new, commands = nil)
      @repo_manager = repo_manager
      @repo_type = 2
      @default_commit_msg = "[Feature]"
      if commands.nil?
        return
      end
      commands.each_index do |index|
        command = commands[index]
        case command
        when  "-a"
          @repo_type = 0
        when "-m"
          @repo_type = 1
        when "--commit-m"
          @default_commit_msg = commands[index + 1]
        else
        end
      end
    end
  
    def run
      read_repo_infos
      commit
      merge
      push_and_create_mr
    end
  
    # 读取组件信息
    def read_repo_infos() 
      main_repo = repo_manager.main_repo
      @command_options = ""
      case repo_type
      when 0
      when 1
        @repos = [main_repo]
        @command_options = " --repo #{main_repo["name"]}"
      else
        @repos = repo_manager.sub_repos
        @command_options = " --no-repo #{main_repo["name"]}"
      end
    end
  
    # 提交代码
    def commit()
      should_commit = false
      repos.each do |repo|
        repo_name = repo["name"]
        FileUtils.cd("#{repo_manager.root_path}/#{repo_name}")
        git_status = `git status --porcelain`
        if !git_status.empty?
          should_commit = true
          break
        end
      end
  
      if should_commit 
        input_msg = Utilities.display_dialog("请输入提交信息：", default_commit_msg.nil? ? "" : default_commit_msg)
        reg = /\[(Feature|Bugfix|Optimization|Debug)\][a-z_A-Z0-9\-\.!@#\$%\\\^&\*\)\(\+=\{\}\[\]\/",'<>~\·`\?:;|\s]+$/
        commit_msg = input_msg.match(reg)
        if commit_msg.nil?
          puts "Error: commit message is malformed".red
          exit(1)
        end
  
        system "mbox git add .#{command_options}"
        system "mbox git commit -m \"#{commit_msg}\"#{command_options}"
      end
    end
  
    # 合并代码
    def merge()
      is_need_merge = Utilities.display_default_dialog("是否需要合并远程代码到本地？")
      if is_need_merge 
        repos.each do |repo|
          system "mbox merge --repo #{repo["name"]}"
        end
      end
    end
  
    # 推送MR
    def push_and_create_mr()
      is_need_creat_mr = Utilities.display_default_dialog("是否需要推送到远程并创建MR？")
      if is_need_creat_mr 
        reviewers = Utilities.display_dialog("请输入审核人员ID：\n子琰(979) 丕臻(1385) 再润(1569) 思保(1922)", "979 1385").split()
        mr_request_assign = ""
        reviewers.each do |reviewer|
        mr_request_assign += " -o merge_request.assign=#{reviewer}"
        end
  
        mr_source_branch = "-o merge_request.remove_source_branch"
        repos.each do |repo|
          repo_name = repo["name"]
          puts repo_name
          repo_target_branch = repo["target_branch"]
          repo_last_branch = repo["last_branch"]
        
          FileUtils.cd("#{repo_manager.root_path}/#{repo_name}")
          log_content = `git log origin/#{repo_target_branch}..#{repo_last_branch} --pretty=format:"%H"`
          if log_content.empty?
            next
          end
          mr_target = "-o merge_request.target=#{repo_target_branch}"
          # mr_title = "-o merge_request.title=#{repo_last_branch}"
          `git push -o merge_request.create #{mr_target} #{mr_source_branch} #{mr_request_assign}`
        end
      end
    end
  
  end

end