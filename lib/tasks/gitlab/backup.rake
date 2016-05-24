require 'active_record/fixtures'

namespace :gitlab do
  namespace :backup do
    # Create backup of GitLab system
    desc "GitLab | Create a backup of the GitLab system"
    task create: :environment do
      warn_user_is_not_gitlab
      configure_cron_mode

      Rake::Task["gitlab:backup:db:create"].invoke
      Rake::Task["gitlab:backup:repo:create"].invoke
      Rake::Task["gitlab:backup:uploads:create"].invoke
      Rake::Task["gitlab:backup:builds:create"].invoke
      Rake::Task["gitlab:backup:artifacts:create"].invoke
      Rake::Task["gitlab:backup:lfs:create"].invoke
      Rake::Task["gitlab:backup:registry:create"].invoke

      backup = Backup::Manager.new
      backup.pack
      backup.cleanup
      backup.remove_old
    end

    # Restore backup of GitLab system
    desc 'GitLab | Restore a previously created backup'
    task restore: :environment do
      warn_user_is_not_gitlab
      configure_cron_mode

      backup = Backup::Manager.new
      backup.unpack

      unless backup.skipped?('db')
        unless ENV['force'] == 'yes'
          warning = warning = <<-MSG.strip_heredoc
            Before restoring the database we recommend removing all existing
            tables to avoid future upgrade problems. Be aware that if you have
            custom tables in the GitLab database these tables and all data will be
            removed.
          MSG
          ask_to_continue
          puts 'Removing all tables. Press `Ctrl-C` within 5 seconds to abort'.yellow
          sleep(5)
        end
        # Drop all tables Load the schema to ensure we don't have any newer tables
        # hanging out from a failed upgrade
        $progress.puts 'Cleaning the database ... '.blue
        Rake::Task['gitlab:db:drop_tables'].invoke
        $progress.puts 'done'.green
        Rake::Task['gitlab:backup:db:restore'].invoke
      end
      Rake::Task['gitlab:backup:repo:restore'].invoke unless backup.skipped?('repositories')
      Rake::Task['gitlab:backup:uploads:restore'].invoke unless backup.skipped?('uploads')
      Rake::Task['gitlab:backup:builds:restore'].invoke unless backup.skipped?('builds')
      Rake::Task['gitlab:backup:artifacts:restore'].invoke unless backup.skipped?('artifacts')
      Rake::Task['gitlab:backup:lfs:restore'].invoke unless backup.skipped?('lfs')
      Rake::Task['gitlab:backup:registry:restore'].invoke unless backup.skipped?('registry')
      Rake::Task['gitlab:shell:setup'].invoke

      backup.cleanup
    end

    namespace :repo do
      task create: :environment do
        $progress.puts "Dumping repositories ...".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("repositories")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Repository.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring repositories ...".blue
        Backup::Repository.new.restore
        $progress.puts "done".green
      end
    end

    namespace :db do
      task create: :environment do
        $progress.puts "Dumping database ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("db")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Database.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring database ... ".blue
        Backup::Database.new.restore
        $progress.puts "done".green
      end
    end

    namespace :builds do
      task create: :environment do
        $progress.puts "Dumping builds ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("builds")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Builds.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring builds ... ".blue
        Backup::Builds.new.restore
        $progress.puts "done".green
      end
    end

    namespace :uploads do
      task create: :environment do
        $progress.puts "Dumping uploads ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("uploads")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Uploads.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring uploads ... ".blue
        Backup::Uploads.new.restore
        $progress.puts "done".green
      end
    end

    namespace :artifacts do
      task create: :environment do
        $progress.puts "Dumping artifacts ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("artifacts")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Artifacts.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring artifacts ... ".blue
        Backup::Artifacts.new.restore
        $progress.puts "done".green
      end
    end

    namespace :lfs do
      task create: :environment do
        $progress.puts "Dumping lfs objects ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("lfs")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Lfs.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring lfs objects ... ".blue
        Backup::Lfs.new.restore
        $progress.puts "done".green
      end
    end

    namespace :registry do
      task create: :environment do
        $progress.puts "Dumping container registry images ... ".blue

        if ENV["SKIP"] && ENV["SKIP"].include?("registry")
          $progress.puts "[SKIPPED]".cyan
        else
          Backup::Registry.new.dump
          $progress.puts "done".green
        end
      end

      task restore: :environment do
        $progress.puts "Restoring container registry images ... ".blue
        Backup::Registry.new.restore
        $progress.puts "done".green
      end
    end

    def configure_cron_mode
      if ENV['CRON']
        # We need an object we can say 'puts' and 'print' to; let's use a
        # StringIO.
        require 'stringio'
        $progress = StringIO.new
      else
        $progress = $stdout
      end
    end
  end # namespace end: backup
end # namespace end: gitlab
