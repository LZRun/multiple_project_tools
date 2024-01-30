module Pixab

  class MboxRemove

    attr_reader :repo_manager

    def initialize(repo_manager)
      @repo_manager = repo_manager
    end

    def run(commands)
      if commands.empty?
        repo_names = @repo_manager.sub_repo_names
        if !repo_names.empty?
          selected_item_names = Utilities.display_choose_list(repo_names, nil, "仓库", "请选择需要移除的仓库：", nil, nil, true)
          selected_item_names.each do |repo_name|
            remove_repo([repo_name.strip])
          end
        end
      elsif commands[0] == "--all"
        repo_names = @repo_manager.sub_repo_names
        repo_names.each do |repo_name|
          remove_repo([repo_name])
        end
      else
        remove_repo(commands)
      end

      system("mbox status")

    end

    def remove_repo(commands)
      return if commands.empty?

      execute_commad = "mbox remove"
      commands.each do |command|
        execute_commad += " #{command}"
      end

      `#{execute_commad}`
    end

  end

end