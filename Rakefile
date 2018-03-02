require 'rubygems'
require 'optparse'
require 'json'

desc "Bootstrap the application and run health checks"
task bootstrap: ["ruby:autocheck", "dependencies:install", "spec"]
task default: [:bootstrap]

task :spec do
  sh "STANDALONE=1 bin/rspec"
end

MAJ, MIN, _REV = RUBY_VERSION.split(".").map(&:to_i)

def check_ruby
  return false if MAJ < 2
  return false if MAJ == 2 && MIN < 1
  true
end

def ask(msg, default = nil)
  if default.nil?
    msg << "\n> "
  else
    msg << "(#{default})> "
  end
  print Array(msg).join("\n")
  val = $stdin.gets.strip
  val = yield val if block_given?
  if val == ""
    default
  else
    val
  end
end

namespace :ruby do
  task :autocheck do
    unless check_ruby
      puts "Your Ruby version is too old."
      raw_options = []

      `which brew`
      raw_options << [:brew, "Homebrew (brew install ruby)"] if $?.success?
      raw_options << [:rvm, "RVM (installs the Ruby Version Manager, which allows you to have multiple versions of Ruby installed at once)"]
      options = raw_options.map.with_index do |(key, msg), index|
        "#{index + 1}) #{msg}"
      end

      option = -1
      while not (1..2).cover?(option)
        option = ask(["Which method would you like to use to install Ruby?"] + options, nil) {|v| v.to_i }
      end

      case raw_options[option - 1].first
      when :brew
        sh "brew install ruby"
        sh "gem install bundler"
      when :rvm
        Rake::Task["ruby:install"].invoke
      end
    end
  end

  desc "Check if your Ruby version is up to date"
  task :check do
    if check_ruby
      puts "Your Ruby version is okay!"
    else
      puts "Your Ruby version is too old. Installing Ruby 2.4.1 + dependencies..."
      puts "You can install RVM and Ruby 2.4.1 by running `rake ruby:install`"
    end
  end

  desc "Installs RVM and Ruby 2.4.1"
  task :install do
    `which rvm`
    if $?.success?
      sh "rvm install 2.4.1 --gems bundler"
      sh "rvm use 2.4.1"
      puts "Ruby is installed!"
    else
      sh "\curl -sSL https://get.rvm.io | bash -s stable --ruby --gems bundler"
      puts "RVM + Ruby installed. Please open a new shell, or run `source ~/.rvm/scripts/rvm` to activate RVM in this shell."
    end
  end
end

namespace :dependencies do
  task :install do
    sh "gem install bundler"
    sh "bundle"
  end
end

def get_ddl_build_opts
end

def run_ddl_build(opts)
  jar = "hive-json-schema-gen-1.0-SNAPSHOT.jar"
  Rake::Task["hive:ddl_builder:install"].invoke unless File.exists? jar
  cmd = "java -cp #{jar} org.amm.hiveschema.HiveJsonSchemaDriver -t #{opts[:table]} -l #{opts[:target]} --serde #{opts[:serde]} --isExternalTable --escapeReservedKeywords #{opts[:file]}"
  sh cmd
  ddl_file = "#{opts[:table]}.ddl"
  File.read ddl_file
end

namespace :hive do
  namespace :ddl_builder do
    task :install do
      `which mvn`
      unless $?.success?
        `which brew`
        if $?.success?
          sh "brew install maven"
        else
          puts "You don't appear to have Homebrew installed. Please install it, or install Maven another way, then re-run `rake hive:ddl_builder:install`"
          return
        end
      end

      sh <<-EOF
        git clone https://github.com/amesar/hive-json-schema-gen
        cd hive-json-schema-gen
        mvn package
        cp target/hive-json-schema-gen-1.0-SNAPSHOT.jar ..
        cd ..
        rm -rf hive-json-schema-gen
      EOF
    end
  end

  desc "Build a DDL schema from a file containing a list of JSON records (one per line)."
  task :build_schema do
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: rake hive:build_schema -- [options]"
      opts.on("-t", "--table TABLE", "Specify the table to use")                       {|val| options[:table] = val  }
      opts.on("-b", "--bucket BUCKET", "Specify the S3 bucket to use")                 {|val| options[:bucket] = val }
      opts.on("-p", "--path PATH", "Specify the S3 path to use")                       {|val| options[:path] = val   }
      opts.on("-P", "--partition PARTITION", [:Y, :N], "Use standard partitioning")    {|val| options[:part] = val   }
      opts.on("-s", "--serde SERDE", "Specify the SerDe to use")                       {|val| options[:serde] = val  }
      opts.on("-f", "--file FILE", "Specify the input file to use")                    {|val| options[:file] = val   }
    end

    args = parser.order!(ARGV) {}
    parser.parse!(args)

    options[:table]  ||= ask "What is the name of the desired Athena table?", "table"
    options[:bucket] ||= ask "What is the S3 bucket of the data?", "mashable-kraken"
    options[:path]   ||= ask "In the bucket, what is the path to the data?", "/path/to/data"
    options[:serde]  ||= ask "Which SerDe class do you want to use?", "org.openx.data.jsonserde.JsonSerDe"
    options[:file]   ||= ask "Where is your input data?", "input.json"
    options[:part]     = ask "Partition with year/month/day partitions?", "Y"

    options[:path] = "/#{options[:path]}/".squeeze("/")
    options[:target] = "s3://#{options[:bucket]}#{options[:path]}"
    opts = options

    ddl = run_ddl_build(opts)

    puts "\nCopy this statement into the Athena Query Editor:"
    puts "-" * 40

    if opts[:part]
      partitions = "PARTITIONED BY (year int, month int, day int)"
      ddl.sub!(/^ROW FORMAT/, "#{partitions}\nROW FORMAT")
    end

    puts "\n#{ddl};\n"
    puts "-" * 40
    puts "\nThen run:"
    puts "-" * 40
    puts "\nMSCK REPAIR TABLE #{opts[:table]};\n\n"
    puts "-" * 40
    exit
  end

  desc "Generate a JSON -> ORC conversion task"
  task :optimize_json do
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: rake hive:optimize_json -- [options]"
      opts.on("-i", "--input INPUT", "Specify the S3 input path")   {|val| options[:input] = val }
      opts.on("-o", "--output OUTPUT", "Specify the S3 output path") {|val| options[:output] = val }
      opts.on("-p", "--input_partitions INPUT_PARTITIONS", "Specify partitioning scheme for input data") {|val| options[:input_partitions] = val }
      opts.on("-P", "--output_partitions OUTPUT_PARTITIONS", "Specify partitioning scheme for output data") {|val| options[:output_partitions] = val }
      opts.on("-c", "--cast CASTS", "Additional statement to select cast values for partitioning") {|val| options[:casts] = val }
      opts.on("-f", "--file FILE", "Specify the input file to use") {|val| options[:file] = val   }
    end

    args = parser.order!(ARGV) {}
    parser.parse!(args)

    options[:input]  ||= ask "What is the S3 location of the input data?"
    options[:output] ||= ask "What is the S3 location of the output data?"
    options[:input_partitions] ||= ask "What is the partioning scheme for the input data?"
    options[:output_partitions] ||= ask "What is the partioning scheme for the output data?"
    options[:casts] ||= ask "What casts are needed for the output partitioning?"
    options[:file]   ||= ask "Where is your input data?", "input.json"

    ddl = run_ddl_build(
      table: "source",
      target: options[:input],
      serde: "org.openx.data.jsonserde.JsonSerDe",
      file: options[:file]
    ).split("ROW FORMAT").first.strip

    dest_ddl = ddl.gsub("TABLE source", "TABLE destination")
    partition_fields = options.fetch(:output_partitions, "").split(",").map {|e| e.split(" ").first }

    build_script = <<-EOF
ADD JAR /usr/lib/hive-hcatalog/share/hcatalog/hive-hcatalog-core-1.0.0-amzn-9.jar;
SET hive.exec.dynamic.partition.mode=nonstrict;

#{ddl}
#{options[:input_partitions] ? "PARTITIONED BY (#{options[:input_partitions]})" : ""}
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
LOCATION '#{options[:input]}';
MSCK REPAIR TABLE source;

#{dest_ddl}
#{options[:output_partitions] ? "PARTITIONED BY (#{options[:output_partitions]})" : ""}
STORED AS ORC
LOCATION '#{options[:output]}';

INSERT OVERWRITE TABLE destination #{"PARTITION" if partition_fields.any?} #{"(#{partition_fields.join(", ")})" if partition_fields.any?}
SELECT #{["*", options.fetch(:casts, "").split(",").map(&:strip)].join(", ")} FROM source;
    EOF
    puts "-" * 40
    puts build_script
    puts "-" * 40
    exit
  end
end
