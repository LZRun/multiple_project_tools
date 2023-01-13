#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"
require 'colored2'
require_relative './Utilities.rb'
require_relative './RepoManager.rb'
require_relative './GitUtils.rb'

module Pixab
  
  class MergeRequest

    attr_accessor :repo_type, :default_commit_msg, :need_merge_origin, :need_creat_mr
    attr_reader :repo_manager, :repos, :command_options
  
    def initialize(repo_manager = RepoManager.new, commands = nil)
      @repo_manager = repo_manager
      @repo_type = 2
      @default_commit_msg = "[Feature]"
      @need_merge_origin = true
      @need_creat_mr = true

      if commands.nil?
        return
      end
      commands.each_index do |index|
        command = commands[index]
        case command
        when "-a"
          @repo_type = 0
        when "-m"
          @repo_type = 1
        when "--commit-m"
          @default_commit_msg = commands[index + 1]
        when "--no-merge-origin"
          @need_merge_origin = false
        when "--no-mr"
          @need_creat_mr = false
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
      if need_merge_origin 
        repos.each do |repo|
          system "mbox merge --repo #{repo["name"]}"
        end
      end
    end
  
    # 推送MR
    def push_and_create_mr()
      if !need_creat_mr
        return
      end

      feature_branch = repo_manager.feature_branch

      reviewers = Utilities.display_dialog("正在创建Merge Request\n请输入审核人员ID：\n子琰(979) 丕臻(1385) 再润(1569) 思保(1922)", "979 1385").split()
      mr_request_assign = ""
      reviewers.each do |reviewer|
        mr_request_assign += " -o merge_request.assign=#{reviewer}"
      end
      mr_source_branch = "-o merge_request.remove_source_branch"

      repos.each do |repo|
        repo_name = repo["name"]
        puts "\n[#{repo_name}]"
        FileUtils.cd("#{repo_manager.root_path}/#{repo_name}")
        current_branch = GitUtils.current_branch
        if current_branch != feature_branch
          puts "\n[!] The repo #{repo_name} is not in feature branch `#{feature_branch}`. Skip it.".yellow
          next
        end
        
        repo_target_branch = repo["target_branch"]          
        
        log_content = `git log origin/#{repo_target_branch}..#{current_branch} --pretty=format:"%H"`
        if log_content.empty?
          puts "\n[!] branch `#{current_branch}` is same as branch `origin/#{repo_target_branch}`. Skip it.".yellow
          next          
        end
        mr_target = "-o merge_request.target=#{repo_target_branch}"
        # mr_title = "-o merge_request.title=#{repo_last_branch}"
        commad = "git push"
        if repo["last_branch"].nil?
          commad += " --set-upstream origin #{current_branch}"
        end
        `#{commad} -o merge_request.create #{mr_target} #{mr_source_branch} #{mr_request_assign}`
      end
    end
  
  end

end