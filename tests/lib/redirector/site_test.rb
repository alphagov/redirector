#!/usr/bin/env ruby
require_relative '../../test_helper'

require 'minitest/unit'
require 'minitest/autorun'
require 'redirector/site'
require 'gds_api/test_helpers/organisations'

class RedirectorSiteTest < MiniTest::Unit::TestCase
  include GdsApi::TestHelpers::Organisations
  include FilenameHelpers

  def setup
    @old_app_domain = ORGANISATIONS_API_ENDPOINT
    ORGANISATIONS_API_ENDPOINT.gsub! /^.*$/, 'https://whitehall-admin.production.alphagov.co.uk'
  end

  def teardown
    ORGANISATIONS_API_ENDPOINT.gsub! /^.*$/, @old_app_domain
  end

  def test_can_initialize_site_from_yml
    site = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    assert_equal 'attorney-generals-office', site.whitehall_slug
    assert_equal 'ago', site.abbr
  end

  def test_decodes_titles
    site = Redirector::Site.from_yaml(site_filename('bis'))
    assert_equal 'Department for Business, Innovation & Skills', site.title
  end

  def test_can_enumerate_all_sites
    organisations_api_has_organisations(%w(attorney-generals-office))
    number_of_sites =
      Dir[Redirector.path('data/sites/*.yml')].length +
      Dir[Redirector.path('data/transition-sites/*.yml')].length

    assert_equal number_of_sites, Redirector::Site.all.length
  end

  def test_all_raises_error_when_no_files
    assert_raises(RuntimeError) do
      Redirector::Site.all(relative_to_tests('fixtures/nosites/*.yml'))
    end
  end

  def test_site_has_whitehall_slug
    organisations_api_has_organisations(%w(attorney-generals-office))
    slug = Redirector::Site.all.first.whitehall_slug
    assert_instance_of String, slug
    refute_empty slug
  end

  def test_sites_never_existed_in_whitehall?
    %w(directgov directgov_microsite businesslink businesslink_microsite).each do |site_abbr|
      site = Redirector::Site.from_yaml(slug_check_site_filename(site_abbr))
      assert site.never_existed_in_whitehall?,
             "Expected that #{site_abbr} never_existed_in_whitehall? to be true, got false"
    end

    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    refute ago.never_existed_in_whitehall?,
           'Expected ago to have existed in whitehall'
  end

  def test_existing_site_slug_exists_in_whitehall?
    organisations_api_has_organisations(%w(attorney-generals-office))
    ago = Redirector::Site.from_yaml(slug_check_site_filename('ago'))
    assert ago.slug_exists_in_whitehall?,
           "expected #{ago.whitehall_slug} to exist in whitehall"
  end

  def test_non_existing_site_slug_does_not_exist_in_whitehall?
    organisations_api_has_organisations(%w(nothing-interesting))
    refute Redirector::Site.from_yaml(slug_check_site_filename('ago')).slug_exists_in_whitehall?,
           'expected slug "attorney-generals-office" not to exist in Mock whitehall'
  end

  def test_checks_all_slugs
    organisations_api_has_organisations(%w(attorney-generals-office paths))

    exception = assert_raises(Redirector::SlugsMissingException) do
      Redirector::Site.check_all_slugs!(relative_to_tests('fixtures/slug_check_sites/*.yml'))
    end

    refute_nil exception.missing.find {|site| site.whitehall_slug == 'non-existent-slug' }
    assert_nil exception.missing.find {|site| site.whitehall_slug == 'directgov_microsite' }
    assert_nil exception.missing.find {|site| site.whitehall_slug == 'directgov' }
  end

  def test_site_create_fails_when_no_slug
    organisations_api_does_not_have_organisation 'non-existent-whitehall-slug'

    assert_raises(ArgumentError) do
      Redirector::Site.create('foobar', 'non-existent-whitehall-slug', 'some.host.gov')
    end
  end

  def test_site_creates_redirector_yaml_when_slug_exists
    organisation_details = organisation_details_for_slug('uk-border-agency').tap do |details|
      details['title'] = 'UK Borders Agency & encoding test'
    end
    organisations_api_has_organisation 'uk-border-agency', organisation_details

    site = Redirector::Site.create('ukba', 'uk-border-agency', 'www.ukba.homeoffice.gov.uk', type: :redirector)

    assert site.filename.include?('data/sites'), 'site.filename should contain data/sites'
  end

  def test_site_create_fails_on_unknown_type
    assert_raises(ArgumentError) do
      Redirector::Site.create('ukba', 'uk-border-agency', 'www.ukba.homeoffice.gov.uk', type: :foobar)
    end
  end

  def test_site_creates_bouncer_yaml_when_slug_exists
    organisation_details = organisation_details_for_slug('uk-border-agency').tap do |details|
      details['title'] = 'UK Borders Agency & encoding test'
    end
    organisations_api_has_organisation 'uk-border-agency', organisation_details

    site = Redirector::Site.create('ukba', 'uk-border-agency', 'www.ukba.homeoffice.gov.uk', type: :bouncer)

    assert site.filename.include?('data/transition-sites'),
           'site.filename should include data/transition-sites'

    assert_equal 'ukba', site.abbr
    assert_equal 'uk-border-agency', site.whitehall_slug
    assert_equal 'UK Borders Agency & encoding test', site.title
    assert_equal 'www.ukba.homeoffice.gov.uk', site.host

    site.save!

    begin
      yaml = YAML.load(File.read(site.filename))

      assert_equal 'ukba', yaml['site']
      assert_equal 'uk-border-agency', yaml['whitehall_slug']
      assert_equal 'UK Borders Agency &amp; encoding test', yaml['title']
      assert_equal 'https://www.gov.uk/government/organisations/uk-border-agency', yaml['homepage']
    ensure
      File.delete(site.filename)
    end
  end

end
