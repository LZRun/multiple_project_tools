#!/usr/bin/env ruby
# encoding: UTF-8

require "fileutils"
require_relative './GitUtils.rb'
require_relative './RepoManager.rb'

module Pixab

  class Package

    attr_reader :repo_manager

    def initialize(repo_manager = RepoManager.new)
      @repo_manager = repo_manager
    end

    def run
      main_repo = repo_manager.main_repo
      package_branch = 'develop'
      origin_package_branch = "origin/#{package_branch}"
      target_branch = main_repo["target_branch"]
      origin_target_branch = "origin/#{target_branch}"
      main_repo_path = "#{repo_manager.root_path}/#{main_repo['name']}"
      FileUtils.cd(main_repo_path)
      GitUtils.check_git_repo(main_repo_path)
      puts "\n》》》》》正在更新远程仓库信息》》》》》\n".green
      GitUtils.fetch_origin
      if !GitUtils.is_branch_synced(origin_package_branch, package_branch)
        puts "\n》》》》》正在将#{origin_package_branch}代码拉取到#{package_branch}》》》》》\n".green
        GitUtils.check_is_code_conflicts(origin_package_branch, package_branch)
        GitUtils.fetch_origin(package_branch, package_branch)
      end
      if !GitUtils.is_branch_synced(origin_target_branch, package_branch)
        puts "\n》》》》》正在将#{origin_target_branch}代码合并到#{package_branch}》》》》》\n".green
        GitUtils.check_is_code_conflicts(origin_target_branch, package_branch)
        GitUtils.fetch_origin(target_branch, package_branch)
      end
      if GitUtils.is_branch_synced(package_branch, origin_package_branch)
        puts "Error: #{package_branch} branch has no code update and cannot be packaged.".red
        exit(1)
      end
      GitUtils.push(package_branch)
      puts "\n》》》》》已完成#{package_branch}代码推送，正在打包》》》》》".green
      puts "打包平台地址：http://ios.meitu-int.com/ipa/airbrush/queue\n".green
    end

  end

end