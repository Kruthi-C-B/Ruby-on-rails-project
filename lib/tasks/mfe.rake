namespace :mfe do
  desc "Build all microfrontends and copy their production bundles to public/mfe"
  task :build do
    admin_dir = Rails.root.join("mfe", "admin-dashboard")
    security_dir = Rails.root.join("mfe", "security-logs")
    public_mfe = Rails.root.join("public", "mfe")

    FileUtils.mkdir_p(public_mfe)

    # Copy already built dist files if present, or build them
    admin_dist = admin_dir.join("dist")
    if admin_dist.exist? && admin_dist.join("localfind-admin-dashboard.js").exist?
      FileUtils.cp_r(Dir.glob(admin_dist.join("*")), public_mfe)
    elsif admin_dir.join("package.json").exist?
      puts "Building admin-dashboard MFE..."
      system("cd #{admin_dir} && npm install --silent && npm run build") || puts("Warning: admin-dashboard MFE build failed or npm missing")
      FileUtils.cp_r(Dir.glob(admin_dist.join("*")), public_mfe) if admin_dist.exist?
    end

    # Copy already built dist files if present, or build them
    security_dist = security_dir.join("dist")
    if security_dist.exist? && security_dist.join("localfind-security-logs.js").exist?
      FileUtils.cp_r(Dir.glob(security_dist.join("*")), public_mfe)
    elsif security_dir.join("package.json").exist?
      puts "Building security-logs MFE..."
      system("cd #{security_dir} && npm install --silent && npm run build") || puts("Warning: security-logs MFE build failed or npm missing")
      FileUtils.cp_r(Dir.glob(security_dist.join("*")), public_mfe) if security_dist.exist?
    end

    puts "MFE bundles placed in #{public_mfe}"
  end
end

if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["mfe:build"])
end
