# frozen_string_literal: true

require 'json'

class Roda
  module RodaPlugins
    # plugin :assets_manifest,
    #   host: { development: "/public/assets", production: "" },
    #   host: "/public/assets"
    #   location: "../../public/assets/manifest.json",
    #   manifest: proc do
    #     {
    #       "app.js" => "app-123.js"
    #     }
    #   end,
    #   is_production: ENV["RACK_ENV"] == "production"
    #
    # js_entrypoint_tag('/name/someting') # /public/assets/name/something.js and /public/assets/name/something-DIGESTED.js

    module AssetsManifest
      DEFAULT_HREF_HOST = '/public/assets'
      DEFAULT_MANIFEST_LOCATION = '/public/assets/manifest.json'
      JS_ENTRYPOINT_TAG_CACHE = {}
      CSS_ENTRYPOINT_TAG_CACHE = {}

      def self.configure(app, opts = {})
        opts[:host] ||= DEFAULT_HREF_HOST

        if opts[:host].is_a?(String)
          app.opts[:assets_manifest_host_development] ||= opts[:host]
          app.opts[:assets_manifest_host_production] ||= opts[:host]
        elsif opts[:host].is_a?(Hash)
          app.opts[:assets_manifest_host_development] ||= opts.dig(:host, :development) || DEFAULT_HREF_HOST
          app.opts[:assets_manifest_host_production] ||=
            opts.dig(:host, :production) || app.opts[:assets_manifest_host_development]
        end

        app.opts[:assets_manifest_is_production] = if opts.key?(:is_production)
                                                     opts[:is_production]
                                                   else
                                                     ENV["RACK_ENV"] == "production"
                                                   end

        if opts[:manifest].respond_to?(:call)
          app.opts[:assets_manifest] = opts[:manifest].call
        else
          location = File.expand_path((opts[:location] || DEFAULT_MANIFEST_LOCATION), __dir__)
          if File.exist?(location)
            app.opts[:assets_manifest] = JSON.parse(File.read(location))
            app.opts[:assets_version] = app.opts[:assets_manifest].hash.to_s
          else
            app.opts[:assets_manifest] = {}
          end
        end
      end

      module InstanceMethods
        def js_entrypoint_tag(entrypoint)
          self.class.js_entrypoint_tag(entrypoint)
        end

        def css_entrypoint_tag(entrypoint)
          self.class.css_entrypoint_tag(entrypoint)
        end

        def assets_version
          self.class.assets_version
        end
      end

      module ClassMethods
        def assets_version = opts[:assets_version]

        def js_entrypoint_tag(entrypoint)
          Roda::RodaPlugins::AssetsManifest::JS_ENTRYPOINT_TAG_CACHE[entrypoint] ||=
            if opts[:assets_manifest_is_production]
              "<script type=\"module\" src=\"#{opts[:assets_manifest_host_production]}/#{opts[:assets_manifest]["#{entrypoint}.js"]}\"></script>"
            else
              "<script type=\"module\" src=\"#{opts[:assets_manifest_host_development]}/#{entrypoint}.js\"></script>"
            end
        end

        def css_entrypoint_tag(entrypoint)
          Roda::RodaPlugins::AssetsManifest::CSS_ENTRYPOINT_TAG_CACHE[entrypoint] ||=
            if opts[:assets_manifest_is_production]
              "<link rel=\"stylesheet\" href=\"#{opts[:assets_manifest_host_production]}/#{opts[:assets_manifest]["#{entrypoint}.css"]}\" />"
            else
              "<link rel=\"stylesheet\" href=\"#{opts[:assets_manifest_host_development]}/#{entrypoint}.css\" />"
            end
        end
      end
    end

    register_plugin(:assets_manifest, AssetsManifest)
  end
end
