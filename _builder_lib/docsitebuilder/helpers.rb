require 'asciidoctor'
require 'find'
require 'git'
require 'logger'
require 'pandoc-ruby'
require 'pathname'
require 'yaml'

module DocSiteBuilder
  module Helpers

    BUILD_FILENAME      = '_build_cfg.yml'
    DISTRO_MAP_FILENAME = '_distro_map.yml'
    BUILDER_DIRNAME     = '_build_system'
    PREVIEW_DIRNAME     = '_preview'
    PACKAGE_DIRNAME     = '_package'
    BLANK_STRING_RE     = Regexp.new('^\s*$')
    PRODUCT_AUTHOR      = "OpenShift Documentation Project <dev@lists.openshift.redhat.com>"
    ANALYTICS_SHIM      = {
      'openshift-origin' => "<script async src=\"//www.google-analytics.com/analytics.js\" type=\"text/javascript\"></script>
<script>
 window.ga=window.ga||function(){(ga.q=ga.q||[]).push(arguments)};ga.l=+new Date;
 ga('create', 'UA-40375612-1', 'openshift.org');
 ga('set', 'forceSSL', true);
 ga('send', 'pageview');
</script>",
      'openshift-online' => "<script type=\"text/javascript\" src=\"https://assets.openshift.net/app/assets/site/tracking.js\"></script>",
      'openshift-enterprise' => "<script type=\"text/javascript\" src=\"https://assets.openshift.net/app/assets/site/tracking.js\"></script>",
    }
    TOPNAV_DEFAULT      = <<EOF
    <div class="navbar navbar-default navbar-openshift" role="navigation">
      <div class="navbar-header">
        <div class="dropdown">
          <a class="dropdown-toggle navbar-menu" href="#" data-toggle="dropdown">
            <span class="navbar-menu-title">
              MENU
            </span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span></a>
          <ul class="dropdown-menu">
            <li>
              <a href="https://www.openshift.com/products">Products</a>
            </li>
            <li class="active">
              <a href="http://docs.openshift.org/latest/welcome/index.html">Documentation</a>
            </li>
            <li>
              <a href="https://developers.openshift.com">Developer Portal</a>
            </li>
            <li>
              <a href="https://openshift.uservoice.com">Vote on Features</a>
            </li>
            <li>
              <a href="https://blog.openshift.com/">Blog</a>
            </li>
            <li class="divider hidden-md hidden-lg"></li>
            <li class="hidden-md hidden-lg">
              <a class="nav-log-in" href="https://openshift.redhat.com/app/console">Log in</a>
            </li>
            <li class="hidden-md hidden-lg">
              <a class="nav-sign-up" href="https://www.openshift.com/app/account/new">Sign up free</a>
            </li>
          </ul>
        </div>
        <a class="navbar-brand" href="/"></a>
        <button class="navbar-toggle collapsed" type="button" data-toggle="collapse" data-target=".navbar-collapse" />
          <span class="sr-only">
            Toggle search
          </span></button>
      </div>
      <div class="navbar-collapse collapse">
        <ul class="nav navbar-nav navbar-right">
          <li>
            <a class="nav-search" href="#" data-toggle="collapse" data-target="#navbar-search-field"><i class="fa fa-search"></i></a>
            <div id="navbar-search-field" class="collapse width col-md-4">
              <form id="cse-search-form" action="https://help.openshift.com/hc/en-us/search" method="get">
                <input id="cse-search-input" class="navbar-search-query form-control" name="query" type="text" placeholder=" Search" tabindex="1" autocomplete="off" autofocus="autofocus" />
                <button class="btn btn-default fa fa-search" type="submit" value="Search"></button>
            </form>
            </div>
          </li>
          <li class="hidden-xs hidden-sm">
            <a class="nav-log-in" href="https://openshift.redhat.com/app/console">Log in</a>
          </li>
          <li class="hidden-xs hidden-sm">
            <a class="nav-sign-up" href="https://www.openshift.com/app/account/new">Sign up free</a>
          </li>
        </ul>
      </div></div>
EOF

    TOPNAV_ORIGIN = <<EOF
    <div class="navbar navbar-default navbar-openshift navbar-origin" role="navigation">
      <div class="navbar-header">
        <a class="navbar-brand origin" href="/"></a>
      </div>
    </div>
EOF

    TOPNAV              = {
      'openshift-origin' => TOPNAV_ORIGIN,
      'openshift-online' => TOPNAV_DEFAULT,
      'openshift-enterprise' => TOPNAV_DEFAULT,
    }

    FOOTER_DEFAULT = <<EOF
    <footer class="footer-openshift">
      <div class="container">
        <div class="row">
          <div class="col-xs-3 col-md-3 logo">
            <a href="https://www.redhat.com/"></a>
          </div>
          <div class="col-xs-9 col-md-9 text-right">
            <a href="https://www.openshift.com/legal/openshift_privacy">
              Privacy Policy
            </a>
            <a href="https://www.openshift.com/legal/services_agreement">
              Terms and Conditions
            </a>
          </div>
        </div>
      </div>
    </footer>
EOF

    FOOTER_ORIGIN = <<EOF
    <footer class="footer-openshift footer-origin">
      <div class="container">
        <div class="row">
          <div class="col-sm-12 col-md-4">
            <a id="footer_logo" href="https://www.redhat.com/">
              <img alt="Red Hat" src="https://assets.openshift.net/app/assets/redhat.svg">
            </a>
          </div>
          <div class="col-sm-12 col-md-4 text-center">
            <a id="powered_by_openshift" title="Powered by OpenShift Online with the DIY Cartridge" href="https://hub.openshift.com/quickstarts/92-do-it-yourself-0-1">
              <img src="https://www.openshift.com/sites/default/files/images/powered-transparent-white.png" alt="Powered by OpenShift Online">
            </a>
          </div>
          <div class="col-sm-12 col-md-4 text-right">
            <div id="footer_social">
              <a href="https://twitter.com/openshift" class="first">
                <span>
                  <i class="fa fa-twitter-square fa-2x fa-inverse"></i>
                </span>
              </a>
              <a href="https://github.com/openshift/origin-server">
                <span>
                  <i class="fa fa-github fa-2x fa-inverse"></i>
                </span>
              </a>
              <a href="https://plus.google.com/communities/114361859072744017486">
                <span>
                  <i class="fa fa-google-plus-square fa-2x fa-inverse"></i>
                </span>
              </a>
              <a href="https://www.facebook.com/openshift">
                <span>
                  <i class="fa fa-facebook-square fa-2x fa-inverse"></i>
                </span>
              </a>
            </div>
          </div>
        </div>
        <div class="row">
          <div class="col-lg-12">
            <div class="attribution">
              <button type="button" class="btn btn-link" data-container="body" data-toggle="popover" data-placement="top" data-content="
                '<a target='_blank' href='https://www.flickr.com/photos/eflon/3655695161/'>Spin</a>' by <a target='_blank' href='https://www.flickr.com/photos/eflon/'>eflon</a>,</br> used under <a target='_blank' href='https://creativecommons.org/licenses/by/2.0/'>CC BY 2.0</a> </br>Color tint added to original">
                Image attribution
              </button>
            </div>
          </div>
        </div>
      </div>
    </footer>
EOF

    FOOTER              = {
      'openshift-origin' => FOOTER_ORIGIN,
      'openshift-online' => FOOTER_DEFAULT,
      'openshift-enterprise' => FOOTER_DEFAULT,
    }


    def source_dir
      @source_dir ||= File.expand_path '../../../', __FILE__
    end

    def template_dir
      @template_dir ||= File.join(source_dir,'_templates')
    end

    def preview_dir
      @preview_dir ||= begin
        lpreview_dir = File.join(source_dir,PREVIEW_DIRNAME)
        if not File.exists?(lpreview_dir)
          Dir.mkdir(lpreview_dir)
        end
        lpreview_dir
      end
    end

    def package_dir
      @package_dir ||= begin
        lpackage_dir = File.join(source_dir,PACKAGE_DIRNAME)
        if not File.exists?(lpackage_dir)
          Dir.mkdir(lpackage_dir)
        end
        lpackage_dir
      end
    end

    def build_date
      Time.now.utc
    end

    def git
      @git ||= Git.open(source_dir)
    end

    def git_checkout branch_name
      target_branch = git.branches.local.select{ |b| b.name == branch_name }[0]
      if not target_branch.nil? and not target_branch.current
        target_branch.checkout
      end
    end

    def git_stash_all
      # See if there are any changes in need of stashing
      @stash_needed = `git status --porcelain` !~ /^\s*$/
      if @stash_needed
        puts "\nNOTICE: Stashing uncommited changes and files in working branch."
        `git stash -a`
      end
    end

    def git_apply_and_drop
      return unless @stash_needed
      puts "\nNOTICE: Re-applying uncommitted changes and files to working branch."
      `git stash apply`
      `git stash drop`
      @stash_needed = false
    end

    # Returns the local git branches; current branch is always first
    def local_branches
      @local_branches ||= begin
        branches = []
        branches << git.branches.local.select{ |b| b.current }[0].name
        branches << git.branches.local.select{ |b| not b.current }.map{ |b| b.name }
        branches.flatten
      end
    end

    def working_branch
      @working_branch ||= local_branches[0]
    end

    def build_config_file
      @build_config_file ||= File.join(source_dir,BUILD_FILENAME)
    end

    def distro_map_file
      @distro_map_file ||= File.join(source_dir, DISTRO_MAP_FILENAME)
    end

    # Protip: Don't cache this! It needs to be reread every time we change branches.
    def build_config
      validate_config(YAML.load_stream(open(build_config_file)))
    end

    def find_topic_files
      file_list = Find.find('.').select{ |path| not path.nil? and path =~ /.*\.adoc$/ and not path =~ /README/ and not path =~ /\/old\// and not path.split('/').length < 3 }
      file_list.map{ |path|
        parts = path.split('/');
        parts[1] + '/' + parts[2].split('.')[0]
      }
    end

    def remove_found_config_files(branch,branch_build_config,branch_topic_files)
      nonexistent_topics = []
      branch_build_config.each do |topic_group|
        tg_dir = topic_group['Dir']
        topic_group['Topics'].each do |topic|
          topic_path = tg_dir + '/' + topic['File']
          result     = branch_topic_files.delete(topic_path)
          if result.nil?
            nonexistent_topics << topic_path
          end
        end
      end
      if nonexistent_topics.length > 0
        puts "\nWARNING: The _build_cfg.yml file on branch '#{branch}' references nonexitanst topics:\n" + nonexistent_topics.map{ |topic| "- #{topic}" }.join("\n")
      end
    end

    def distro_map
      @distro_map ||= YAML.load_file(distro_map_file)
    end

    def site_map
      site_map = {}
      distro_map.each do |distro,distro_config|
        if not site_map.has_key?(distro_config["site"])
          site_map[distro_config["site"]] = {}
        end
        site_map[distro_config["site"]][distro] = distro_config["branches"]
      end
      site_map
    end

    def distro_branches(use_distro='')
      @distro_branches ||= begin
        use_distro_list = use_distro == '' ? distro_map.keys : [use_distro]
        distro_map.select{ |dkey,dval| use_distro_list.include?(dkey) }.map{ |distro,dconfig| dconfig["branches"].keys }.flatten
      end
    end

    def page(args)
      page_css = ''
      args[:css].each do |sheet|
        sheet_href = args[:css_path] + sheet
        page_css << "<link href=\"#{sheet_href}\" rel=\"stylesheet\" />\n"
      end

      # TODO: This process of rebuilding the entire nav for every page will not scale well.
      #       As the doc set increases, we will need to think about refactoring this.
      page_nav = ['      <ul class="nav nav-sidebar">']
      groupidx = 0
      breadcrumb_root  = ''
      breadcrumb_group = ''
      breadcrumb_topic = ''
      first_group = true
      args[:navigation].each do |topic_group|
        current_group = topic_group[:id] == args[:group_id]
        page_nav << "        <li class=\"nav-header\">"
        page_nav << "          <a class=\"\" href=\"#\" data-toggle=\"collapse\" data-target=\"#topicGroup#{groupidx}\"><span class=\"fa #{current_group ? 'fa-angle-down' : 'fa-angle-right'}\"></span>#{topic_group[:name]}</a>"
        page_nav << "          <ul id=\"topicGroup#{groupidx}\" class=\"collapse #{current_group ? 'in' : ''} list-unstyled\">"
        first_topic = true
        topic_group[:topics].each do |topic|
          current_topic = topic[:id] == args[:topic_id]
          page_nav << "           <li><a class=\"#{current_topic ? ' active' : ''}\" href=\"#{topic[:path]}\">#{topic[:name]}</a></li>"
          if first_group and first_topic
            breadcrumb_root = "<a href=\"#{topic[:path]}\">#{args[:distro]} #{args[:version]}</a>"
            first_group = false
          end
          if current_group and first_topic
            breadcrumb_group = "<a href=\"#{topic[:path]}\">#{topic_group[:name]}</a>"
            first_topic = false
          end
          if current_topic
            breadcrumb_topic = topic[:name]
          end
        end
        page_nav << '          </ul>'
        page_nav << '         </li>'
        groupidx = groupidx + 1
      end
      page_nav << '       </ul>'

      page_head = <<EOF
<!DOCTYPE html>
<!--[if IE 8]> <html class="ie8"> <![endif]-->
<!--[if IE 9]> <html class="ie9"> <![endif]-->
<!--[if gt IE 9]><!-->
<html>
<!--<![endif]-->
<head>
<meta charset="utf-8">
<meta content="IE=edge" http-equiv="X-UA-Compatible">
<meta content="width=device-width, initial-scale=1.0" name="viewport">
<title>#{args[:distro]} #{args[:version]} | #{args[:group_title]} | #{args[:topic_title]}</title>
<link href="https://assets.openshift.net/content/subdomain.css" rel="stylesheet" type="text/css">
#{page_css}
<script src="https://code.jquery.com/jquery-2.1.1.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"></script>
<script src="#{args[:javascripts_path]}bootstrap-offcanvas.js" type="text/javascript"></script>
<script src="https://assets.openshift.net/content/modernizr.js" type="text/javascript"></script>
<link href="https://assets.openshift.net/content/subdomain/touch-icon-precomposed.png" rel="apple-touch-icon-precomposed" type="image/png">
<link href="https://assets.openshift.net/content/subdomain/favicon32x32.png" rel="shortcut icon" type="text/css">
<!--[if IE]><link rel="shortcut icon" href="https://assets.openshift.net/content/subdomain/favicon.ico"><![endif]-->
<!-- or, set /favicon.ico for IE10 win -->
<meta content="OpenShift" name="application-name">
<meta content="#000000" name="msapplication-TileColor">
<meta content="https://assets.openshift.net/content/subdomain/touch-icon-precomposed.png" name="msapplication-TileImage">
<!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
<!--[if lt IE 9]>
  <script src="https://assets.openshift.net/content/html5shiv.js" type="text/javascript"></script>
  <script src="https://assets.openshift.net/content/respond.js" type="text/javascript"></script>
  <link href="https://assets.openshift.net/content/vendor/respond-js/respond-proxy.html" id="respond-proxy" rel="respond-proxy">
  <link href="#{args[:images_path]}respond.proxy.gif" id="respond-redirect" rel="respond-redirect">
  <script src="#{args[:javascripts_path]}respond.proxy.js" type="text/javascript"></script>
<![endif]-->
#{args[:analytics_shim]}
</head>
<body>
#{args[:topnav]}
<div class="container">
  <p class="toggle-nav visible-xs pull-left">
    <button class="btn btn-default btn-sm" type="button" data-toggle="offcanvas">Toggle nav</button>
  </p>
  <ol class="breadcrumb">
        <li class="sitename">
          <a href="#{args[:site_home_path]}">#{args[:sitename]}</a>
        </li>
        <li class="hidden-xs active">
          #{breadcrumb_root}
        </li>
        <li class="hidden-xs active">
          #{breadcrumb_group}
        </li>
        <li class="hidden-xs active">
          #{breadcrumb_topic}
        </li>
      </ol>
  <div class="row row-offcanvas row-offcanvas-left">
    <div class="col-xs-8 col-sm-3 col-md-3 sidebar sidebar-offcanvas">
EOF

      page_body = <<EOF
    </div>
    <div class="col-xs-12 col-sm-9 col-md-9 main">
      <div class="page-header">
        <h2>#{args[:article_title]}</h2>
      </div>
      #{args[:content]}
    </div>
  </div>
</div>
<script type="text/javascript">
/*<![CDATA[*/
$(document).ready(function() {
  $("[id^='topicGroup']").on('show.bs.collapse', function () {
    $(this).parent().find("span").toggleClass("fa-angle-right fa-angle-down");
  });
  $("[id^='topicGroup']").on('hide.bs.collapse', function () {
    $(this).parent().find("span").toggleClass("fa-angle-right fa-angle-down");
  });
});
/*]]>*/
</script>
#{args[:footer]}
</body>
</html>
EOF

      page_txt = ''
      page_txt << page_head
      page_txt << "\n"
      page_txt << page_nav.join("\n")
      page_txt << "\n"
      page_txt << page_body
      page_txt
    end

    def parse_distros distros_string, for_validation=false
      values = distros_string.split(',').map{ |v| v.strip }
      return values if for_validation
      return distro_map.keys if values.include?('all')
      return values.uniq
    end

    def validate_distros distros_string
      return false if not distros_string.is_a?(String)
      values = parse_distros(distros_string, true)
      values.each do |v|
        return false if not v == 'all' or not distro_map.keys.include?(v)
      end
      return true
    end

    def validate_config config_data
      # Validate/normalize the config file straight away
      if not config_data.is_a?(Array)
        raise "The configuration in #{build_config_file} is malformed; the build system is expecting an array of topic groups."
      end
      config_data.each do |topic_group|
        # Check for presence of topic group keys
        ['Name','Dir','Topics'].each do |group_key|
          if not topic_group.has_key?(group_key)
            raise "One of the topic groups in #{build_config_file} is missing the '#{group_key}' key."
          end
        end
        # Check for right format of topic group values
        ['Name','Dir'].each do |group_key|
          if not topic_group[group_key].is_a?(String)
            raise "One of the topic groups in #{build_config_file} is not using a string for the #{group_key} setting; current value is #{topic_group[group_key].inspect}"
          end
          if topic_group[group_key].empty? or topic_group[group_key].match BLANK_STRING_RE
            raise "One of the topic groups in #{build_config_file} is using a blank value for the #{group_key} setting."
          end
        end
        if not File.exists?(File.join(source_dir,topic_group['Dir']))
          raise "In #{build_config_file}, the directory #{topic_group['Dir']} for topic group #{topic_group['Name']} does not exist under #{source_dir}"
        end
        # Validate the Distros setting
        if topic_group.has_key?('Distros')
          if not validate_distros(topic_group['Distros'])
            key_list = distro_map.keys.map{ |k| "'#{k}'" }.sort.join(', ')
            raise "In #{build_config_file}, the Distros value #{topic_group['Distros'].inspect} for topic group #{topic_group['Name']} is not valid. Legal values are 'all', #{key_list}, or a comma-separated list of legal values."
          end
          topic_group['Distros'] = parse_distros(topic_group['Distros'])
        else
          topic_group['Distros'] = parse_distros('all')
        end
        if not topic_group['Topics'].is_a?(Array)
          raise "The #{topic_group['Name']} topic group in #{build_config_file} is malformed; the build system is expecting an array of 'Topic' definitions."
        end
        # Generate an ID for this topic group
        topic_group['ID'] = camelize topic_group['Name']
        # Now buzz through the topics
        topic_group['Topics'].each do |topic|
          ['Name','File'].each do |topic_key|
            if not topic[topic_key].is_a?(String)
              raise "In #{build_config_file}, topic group #{topic_group['Name']}, one of the topics is not using a string for the '#{topic_key}' setting; current value is #{topic[topic_key].inspect}"
            end
            if topic[topic_key].empty? or topic[topic_key].match BLANK_STRING_RE
              raise "In #{build_config_file}, topic group #{topic_group['Name']}, one of the topics is using a blank value for the '#{topic_key}' setting"
            end
          end
          # Normalize the filenames
          if topic['File'].end_with?('.adoc')
            topic['File'] = topic['File'][0..-6]
          end
          if not File.exists?(File.join(source_dir,topic_group['Dir'],"#{topic['File']}.adoc"))
            raise "In #{build_config_file}, could not find file #{topic['File']} under directory #{topic_group['Dir']} for topic #{topic['Name']} in topic group #{topic_group['Name']}."
          end
          if topic.has_key?('Distros')
            if not validate_distros(topic['Distros'])
              key_list = distro_map.keys.map{ |k| "'#{k}'" }.sort.join(', ')
              raise "In #{build_config_file}, the Distros value #{topic_group['Distros'].inspect} for topic item #{topic['Name']} in topic group #{topic_group['Name']} is not valid. Legal values are 'all', #{key_list}, or a comma-separated list of legal values."
            end
            topic['Distros'] = parse_distros(topic['Distros'])
          else
            topic['Distros'] = parse_distros('all')
          end
          # Generate an ID for this topic
          topic['ID'] = "#{topic_group['ID']}::#{camelize(topic['Name'])}"
        end
      end
      config_data
    end

    def camelize text
      text.split(' ').map{ |t| t.capitalize }.join
    end

    def nav_tree distro, branch_build_config
      navigation = []
      branch_build_config.each do |topic_group|
        next if not topic_group['Distros'].include?(distro)
        next if topic_group['Topics'].select{ |t| t['Distros'].include?(distro) }.length == 0
        topic_list = []
        topic_group['Topics'].each do |topic|
          next if not topic['Distros'].include?(distro)
          topic_list << {
            :path => "../#{topic_group['Dir']}/#{topic['File']}.html",
            :name => topic['Name'],
            :id   => topic['ID'],
          }
        end
        navigation << { :name => topic_group['Name'], :id => topic_group['ID'], :topics => topic_list }
      end
      navigation
    end

    def asciidoctor_page_attrs(more_attrs=[])
      [
        'source-highlighter=coderay',
        'coderay-css=style',
        'linkcss!',
        'icons=font',
        'idprefix=',
        'idseparator=-',
        'sectanchors',
      ].concat(more_attrs)
    end

    def generate_docs(build_distro,single_page=nil)
      single_page_dir = nil
      single_page_file = nil
      if not single_page.nil?
        single_page_dir = single_page.split(':')[0]
        single_page_file = single_page.split(':')[1]
        puts "Rebuilding '#{single_page_dir}/#{single_page_file}' on branch '#{working_branch}'."
      end

      if not build_distro == ''
        if not distro_map.has_key?(build_distro)
          exit
        else
          puts "Building only the #{distro_map[build_distro]["name"]} distribution."
        end
      elsif single_page.nil?
        puts "Building all distributions."
      end

      # First, notify the user of missing local branches
      missing_branches = []
      distro_branches(build_distro).sort.each do |dbranch|
        next if local_branches.include?(dbranch)
        missing_branches << dbranch
      end
      if missing_branches.length > 0 and single_page.nil?
        puts "\nNOTE: The following branches do not exist in your local git repo:"
        missing_branches.each do |mbranch|
          puts "- #{mbranch}"
        end
        puts "The build will proceed but these branches will not be generated."
      end

      # Generate all distros for every local branch
      local_branches.each do |local_branch|
        # Single-page regen only occurs for the working branch
        if not local_branch == working_branch
          if single_page.nil?
            # Checkout the branch
            puts "\nCHANGING TO BRANCH '#{local_branch}'"
            git_checkout(local_branch)
          else
            next
          end
        end

        if local_branch =~ /^\(detached from .*\)/
          local_branch = 'detached'
        end

        # The branch_orphan_files list starts with the set of all
        # .adoc files found in the repo, and will be whittled
        # down from there.
        branch_orphan_files = find_topic_files
        branch_build_config = build_config
        remove_found_config_files(local_branch,branch_build_config,branch_orphan_files)

        if branch_orphan_files.length > 0
          puts "\nWARNING: Branch '#{local_branch}' includes the following .adoc files that are not referenced in the _build_cfg.yml file:\n" + branch_orphan_files.map{ |file| "- #{file}" }.join("\n")
        end

        # Every file included in the build_config can be eliminated
        # from the orphan list.
        # branch_orphan_files =

        # Run all distros.
        distro_map.each do |distro,distro_config|
          # Only building a single distro; skip the others.
          if not build_distro == '' and not build_distro == distro
            next
          end

          sitename = distro_config["site"] == 'community' ? "OpenShift Community Documentation" : "OpenShift Product Documentation"

          first_branch = single_page.nil?

          branch_config = { "name" => "Branch Build", "dir" => local_branch }
          dev_branch    = true
          if distro_config["branches"].has_key?(local_branch)
            branch_config = distro_config["branches"][local_branch]
            dev_branch    = false
          end

          if first_branch
            puts "\nBuilding #{distro_config["name"]} for branch '#{local_branch}'"
            first_branch = false
          end

          # Create the target dir
          branch_path = File.join(preview_dir,distro,branch_config["dir"])
          system("mkdir -p #{branch_path}/stylesheets")
          system("mkdir -p #{branch_path}/javascripts")
          system("mkdir -p #{branch_path}/images")

          # Copy stylesheets into preview area
          system("cp -r _stylesheets/*css #{branch_path}/stylesheets")

          # Copy javascripts into preview area
          system("cp -r _javascripts/*js #{branch_path}/javascripts")

          # Copy images into preview area
          system("cp -r _images/* #{branch_path}/images")

          # Build the landing page
          navigation = nav_tree(distro,branch_build_config)

          # Build the topic files for this branch & distro
          branch_build_config.each do |topic_group|
            next if not topic_group['Distros'].include?(distro)
            next if topic_group['Topics'].select{ |t| t['Distros'].include?(distro) }.length == 0
            next if not single_page.nil? and not single_page_dir == topic_group['Dir']
            src_group_path = File.join(source_dir,topic_group['Dir'])
            tgt_group_path = File.join(branch_path,topic_group['Dir'])
            if not File.exists?(tgt_group_path)
              Dir.mkdir(tgt_group_path)
            end
            topic_group['Topics'].each do |topic|
              next if not topic['Distros'].include?(distro)
              next if not single_page.nil? and not topic['File'] == single_page_file
              src_file_path = File.join(src_group_path,"#{topic['File']}.adoc")
              tgt_file_path = File.join(tgt_group_path,"#{topic['File']}.html")
              if single_page.nil?
                puts "  - #{File.join(topic_group['Dir'],topic['File'])}"
              end
              topic_adoc    = File.open(src_file_path,'r').read
              page_attrs    = asciidoctor_page_attrs([
                "imagesdir=#{src_group_path}/images",
                distro,
                "product-title=#{distro_config["name"]}",
                "product-version=#{branch_config["name"]}",
                "product-author=#{PRODUCT_AUTHOR}"
              ])

              # Because we render only the body of the article with AsciiDoctor, the full article title
              # would be lost in conversion. So, read it out of the raw asciidoc and pass it in to our
              # page renderer
              article_title  = topic_adoc.split("\n")[0].gsub(/^\=\s+/, '').gsub(/\s+$/, '').gsub(/\{product-title\}/, distro_config["name"]).gsub(/\{product-version\}/, branch_config["name"])

              topic_html     = Asciidoctor.render topic_adoc, :header_footer => false, :safe => :unsafe, :attributes => page_attrs
              dir_depth = ''
              if branch_config['dir'].split('/').length > 1
                dir_depth = '../' * (branch_config['dir'].split('/').length - 1)
              end
              full_file_text = page({
                :distro        => distro_config["name"],
                :sitename      => sitename,
                :version       => branch_config["name"],
                :group_title   => topic_group['Name'],
                :topic_title   => topic['Name'],
                :article_title => article_title,
                :content       => topic_html,
                :navigation    => navigation,
                :group_id      => topic_group['ID'],
                :topic_id      => topic['ID'],
                :css_path      => "../../#{dir_depth}#{branch_config["dir"]}/stylesheets/",
                :javascripts_path => "../../#{dir_depth}#{branch_config["dir"]}/javascripts/",
                :images_path      => "../../#{dir_depth}#{branch_config["dir"]}/images/",
                :site_home_path   => "../../#{dir_depth}index.html",
                :css         => [
                  'docs.css',
                ],
                :analytics_shim => ANALYTICS_SHIM[distro],
                :topnav => TOPNAV[distro],
                :footer => FOOTER[distro],
              })
              File.write(tgt_file_path,full_file_text)
              if not single_page.nil?
                return
              end
            end
          end

          # Create a distro landing page
          # This is backwards compatible code. We can remove it when no
          # official repo uses index.adoc. We are moving to flat HTML
          # files for index.html
          src_file_path = File.join(source_dir,'index.adoc')
          if File.exists?(src_file_path)
            topic_adoc    = File.open(src_file_path,'r').read
            page_attrs    = asciidoctor_page_attrs([
              "imagesdir=#{File.join(source_dir,'_site_images')}",
              distro,
              "product-title=#{distro_config["name"]}",
              "product-version=Updated #{build_date}",
              "product-author=#{PRODUCT_AUTHOR}"
            ])
            topic_html = Asciidoctor.render topic_adoc, :header_footer => true, :safe => :unsafe, :attributes => page_attrs
            File.write(File.join(preview_dir,distro,'index.html'),topic_html)
          end
        end

        if local_branch == working_branch
          # We're moving away from the working branch, so save off changed files
          git_stash_all
        end
      end

      # Return to the original branch
      git_checkout(working_branch)

      # If necessary, restore temporarily stashed files
      git_apply_and_drop

      puts "\nAll builds completed."
    end

    # package_docs
    # This method generates the docs and then organizes them the way they will be arranged
    # for the production websites.
    def package_docs(package_site)
      site_map.each do |site,site_config|
        next if not package_site == '' and not package_site == site
        puts "\nBuilding #{site} site."
        site_config.each do |distro,branches|
          branches.each do |branch,branch_config|
            src_dir  = File.join(preview_dir,distro,branch_config["dir"])
            tgt_tdir = branch_config["dir"].split('/')
            tgt_tdir.pop
            tgt_dir  = ''
            if tgt_tdir.length > 0
              tgt_dir = File.join(package_dir,site,tgt_tdir.join('/'))
            else
              tgt_dir = File.join(package_dir,site)
            end
            next if not File.directory?(src_dir)
            FileUtils.mkdir_p(tgt_dir)
            FileUtils.cp_r(src_dir,tgt_dir)
          end
          if File.directory?(File.join(package_dir,site))
            # With this update, site index files will always come from the master branch
            working_branch_site_index = File.join(source_dir,'index-' + site + '.html')
            if File.exists?(working_branch_site_index)
              FileUtils.cp(working_branch_site_index,File.join(package_dir,site,'index.html'))
              ['_images','_stylesheets'].each do |support_dir|
                FileUtils.cp_r(File.join(source_dir,support_dir),File.join(package_dir,site,support_dir))
              end
            else
              FileUtils.cp(File.join(preview_dir,distro,'index.html'),File.join(package_dir,site,'index.html'))
            end
          end
        end
      end
    end
  end
end
