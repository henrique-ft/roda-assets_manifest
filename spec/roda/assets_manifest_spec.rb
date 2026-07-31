# frozen_string_literal: true

require "roda"
require "json"

RSpec.describe "Roda::RodaPlugins::AssetsManifest" do
  def app(opts = {})
    app_class = Class.new(Roda)
    app_class.plugin :assets_manifest, opts
    app_class
  end

  let(:manifest_json) { { "app.js" => "app-123.js", "style.css" => "style-456.css" }.to_json }

  before do
    Roda::RodaPlugins::AssetsManifest::JS_ENTRYPOINT_TAG_CACHE.clear
    Roda::RodaPlugins::AssetsManifest::CSS_ENTRYPOINT_TAG_CACHE.clear
  end

  describe "configuration" do
    describe "opts[:host]" do
      it "defaults to /public/assets for development and production" do
        a = app
        expect(a.opts[:assets_manifest_host_development]).to eq("/public/assets")
        expect(a.opts[:assets_manifest_host_production]).to eq("/public/assets")
      end

      it "uses string value for both development and production" do
        a = app(host: "/cdn/assets")
        expect(a.opts[:assets_manifest_host_development]).to eq("/cdn/assets")
        expect(a.opts[:assets_manifest_host_production]).to eq("/cdn/assets")
      end

      it "uses hash value for respective environments" do
        a = app(host: { development: "/local", production: "https://cdn.com/assets" })
        expect(a.opts[:assets_manifest_host_development]).to eq("/local")
        expect(a.opts[:assets_manifest_host_production]).to eq("https://cdn.com/assets")
      end

      it "falls back to development host if production host is not provided in hash" do
        a = app(host: { development: "/local" })
        expect(a.opts[:assets_manifest_host_production]).to eq("/local")
      end
    end

    describe "opts[:is_production]" do
      it "uses explicitly provided true boolean" do
        a = app(is_production: true)
        expect(a.opts[:assets_manifest_is_production]).to be true
      end

      it "uses explicitly provided false boolean" do
        a = app(is_production: false)
        expect(a.opts[:assets_manifest_is_production]).to be false
      end

      it "falls back to ENV['RACK_ENV'] if not provided" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RACK_ENV").and_return("production")
        a = app
        expect(a.opts[:assets_manifest_is_production]).to be true

        allow(ENV).to receive(:[]).with("RACK_ENV").and_return("development")
        a = app
        expect(a.opts[:assets_manifest_is_production]).to be false
      end
    end

    describe "opts[:manifest] and opts[:location]" do
      it "uses callable if :manifest is a proc" do
        a = app(manifest: -> { { "app.js" => "app-123.js" } })
        expect(a.opts[:assets_manifest]).to eq({ "app.js" => "app-123.js" })
      end

      it "loads from file if location exists" do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return(manifest_json)
        
        a = app(location: "manifest.json")
        expect(a.opts[:assets_manifest]).to eq({ "app.js" => "app-123.js", "style.css" => "style-456.css" })
        expect(a.opts[:assets_version]).to eq(a.opts[:assets_manifest].hash.to_s)
      end

      it "defaults to empty hash if file does not exist" do
        allow(File).to receive(:exist?).and_return(false)
        a = app
        expect(a.opts[:assets_manifest]).to eq({})
      end
    end
  end

  describe "ClassMethods" do
    describe "#assets_version" do
      it "returns the assets version" do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return(manifest_json)
        
        a = app(location: "manifest.json")
        expect(a.assets_version).to eq(JSON.parse(manifest_json).hash.to_s)
      end
    end

    describe "#js_entrypoint_tag" do
      it "returns development script tag" do
        a = app(is_production: false)
        expect(a.js_entrypoint_tag("app")).to eq('<script type="module" src="/public/assets/app.js"></script>')
      end

      it "returns production script tag using manifest" do
        a = app(is_production: true, manifest: -> { { "app.js" => "app-123.js" } })
        expect(a.js_entrypoint_tag("app")).to eq('<script type="module" src="/public/assets/app-123.js"></script>')
      end

      it "caches the tag" do
        a = app(is_production: false)
        expect(a.js_entrypoint_tag("app")).to eq('<script type="module" src="/public/assets/app.js"></script>')
        expect(Roda::RodaPlugins::AssetsManifest::JS_ENTRYPOINT_TAG_CACHE["app"]).to eq('<script type="module" src="/public/assets/app.js"></script>')
      end
    end

    describe "#css_entrypoint_tag" do
      it "returns development link tag" do
        a = app(is_production: false)
        expect(a.css_entrypoint_tag("style")).to eq('<link rel="stylesheet" href="/public/assets/style.css" />')
      end

      it "returns production link tag using manifest" do
        a = app(is_production: true, manifest: -> { { "style.css" => "style-456.css" } })
        expect(a.css_entrypoint_tag("style")).to eq('<link rel="stylesheet" href="/public/assets/style-456.css" />')
      end

      it "caches the tag" do
        a = app(is_production: false)
        expect(a.css_entrypoint_tag("style")).to eq('<link rel="stylesheet" href="/public/assets/style.css" />')
        expect(Roda::RodaPlugins::AssetsManifest::CSS_ENTRYPOINT_TAG_CACHE["style"]).to eq('<link rel="stylesheet" href="/public/assets/style.css" />')
      end
    end
  end

  describe "InstanceMethods" do
    let(:instance) { app(manifest: -> { { "app.js" => "app-123.js", "style.css" => "style-456.css" } }).new({}) }

    it "delegates js_entrypoint_tag to class" do
      expect(instance.class).to receive(:js_entrypoint_tag).with("app")
      instance.js_entrypoint_tag("app")
    end

    it "delegates css_entrypoint_tag to class" do
      expect(instance.class).to receive(:css_entrypoint_tag).with("style")
      instance.css_entrypoint_tag("style")
    end

    it "delegates assets_version to class" do
      expect(instance.class).to receive(:assets_version)
      instance.assets_version
    end
  end
end
