#!/usr/bin/env ruby
# encoding: UTF-8

require 'open3'
require_relative './Utilities.rb'

module Pixab

  class GitUtils

  end
  
  class << GitUtils
    
    # 判断当前是否为git仓库
    def is_git_repo()
      is_git_repo = `git rev-parse --is-inside-work-tree`.chomp
      return is_git_repo == "true"
    end
  
    # 检查当前是否有未提交的代码
    def has_uncommit_code()
      git_status = `git status -s`
      return !git_status.empty?
    end
  
    # 检查指定分支是否关联了远程分支
    def has_remote_branch(branch="HEAD")
      branch_full_name = `git rev-parse --symbolic-full-name #{branch}`
      remote_branch = `git for-each-ref --format='%(upstream:short)' #{branch_full_name}`.chomp
      return !remote_branch.empty?
    end
  
    # 检查指定分支的本地代码和远程代码是否已经同步
    def is_local_and_remote_branch_synced(branch)
      local_log = `git log #{branch} -n 1 --pretty=format:"%H"`
      remote_log = `git log remotes/origin/#{branch} -n 1 --pretty=format:"%H"`
      return local_log == remote_log
    end

    # 判断branch1的代码是否已经同步到branch2
    def is_branch_synced(branch1, branch2)
      if branch1.nil? || branch2.nil?
        return true
      end
      unsynced_commit = `git cherry #{branch2} #{branch1}`
      return unsynced_commit.empty?
    end

    # 获取指定分支的最新提交
    def latest_commit_id(branch)
      return `git log #{branch} -n 1 --pretty=format:"%H"`
    end

    # 拉取远程仓库信息
    # 未指定origin分支时，拉取所有远程仓库信息
    # 只指定origin分支时，拉取远程仓库指定分支信息
    # 同时指定local分支时，拉取远程仓库指定分支信息后，会将远程分支合并到local分支
    def fetch_origin(origin = nil, local = nil)
      commad = "git fetch origin"
      if origin.nil?
        return Utilities.execute_shell(commad)
      end
      commad += " #{origin}"
      if local.nil?
        return Utilities.execute_shell(commad)
      end
      commad += ":#{local}"
      return Utilities.execute_shell(commad)
    end

    # 检查当前分支是否有冲突内容
    def is_code_conflicts_in_current_branch
      `git --no-pager diff --check`
      return !Utilities.is_shell_execute_success
    end

    # 检查两个分支是否存在冲突
    def is_code_conflicts(branch1, branch2)
      conflicts = `git diff --name-status #{branch1} #{branch2} | grep "^U"`
      return !conflicts.empty?
    end
  
    # 获取当前分支
    def current_branch
      branch = `git rev-parse --abbrev-ref HEAD`.chomp
      return branch
    end

    # 推送代码
    # branch: 指定推送分支
    def push(branch = nil)
      commad = "git push"
      if !branch.nil?
        commad += " origin #{branch}"
      end
      return Utilities.execute_shell(commad)
    end

    # 获取当前分支的远程分支
    def current_remote_branch
      local_branch = current_branch
      return nil if local_branch.nil?

      remote_branch, status = Open3.capture2("git for-each-ref --format='%(upstream:short)' refs/heads/#{local_branch}")
      remote_branch.strip!
      return nil if !status.success? || remote_branch.empty?

      return nil unless check_remote_branch_exists_fast(remote_branch)
      return remote_branch 
    rescue => e
      puts "Error: get current remote branch failed, #{e.message}".red
      return nil
    end

    # 在远程仓库检查远程分支是否存在
    # remote_branch: 远程分支名称，不需要remote前缀，使用origin作为remote
    def check_remote_branch_exists(remote_branch)
      exisit_remote_branch, status= Open3.capture2("git ls-remote --heads origin #{remote_branch}")
      return status.success? && !exisit_remote_branch.strip.empty?
    rescue => e
      puts "Error: check remote branch exists failed, #{e.message}".red
      return false
    end

    # 在本地仓库检查远程分支是否存在
    # remote_branch: 远程分支名称
    def check_remote_branch_exists_fast(remote_branch)
      exisit_remote_branch, status = Open3.capture2("git branch -r --list #{remote_branch}")
      status.success? && !exisit_remote_branch.strip.empty?
    end

  end

  class << GitUtils

    def check_git_repo(path)
      if !is_git_repo
        puts "Error: #{path} is not a git repository".red
        exit(1)
      end
    end

    def check_has_uncommit_code(path)
      if has_uncommit_code
        puts "Please commit first, project path: #{path}".red
        exit(1)
      end
    end

    def check_local_and_remote_branch_synced(branch)
      if !is_local_and_remote_branch_synced
        puts "Please sync remote branch, use `git pull` or `git push`".red
        exit(1)
      end
    end

    def check_is_code_conflicts_in_current_branch
      is_code_conflicts = is_code_conflicts_in_current_branch()
      if !is_code_conflicts
        return
      end
      project = File.basename(Dir.pwd)
      conflict_hint = "Error: code conflict!\n"
      conflict_hint += "step1: Resolve project:#{project}, branch:#{current_branch} code conflicts\n"
      conflict_hint += "step2: Execute this script again"
      puts conflict_hint.red
      exit(1)
    end

    def check_is_code_conflicts(branch1, branch2)
      if is_code_conflicts(branch1, branch2)
        puts "Error: #{branch1} and #{branch2} has code conflicts".red
        exit(1)
      end
    end

  end

end