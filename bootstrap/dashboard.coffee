filings = null
appSettings = null

committeeTypes =
  'C': 'Communication Cost'
  'D': 'Delegate'
  'E': 'Electioneering Communication'
  'H': 'House'
  'I': 'Independent Expenditor (Person or Group)'
  'N': 'PAC - Nonqualified'
  'O': 'Independent Expenditure-Only (Super PAC)'
  'P': 'Presidential'
  'Q': 'PAC - Qualified'
  'S': 'Senate'
  'U': 'Single Candidate Independent Expenditure'
  'X': 'Party Nonqualified'
  'Y': 'Party Qualified'
  'Z': 'National Party Nonfederal Account'


class Filing extends Backbone.Model

  initialize: ->
    @set committee_id: @get('committee').match(/\/(C\d+)/)[1]
    @set full_committee_type: committeeTypes[@get('committee_type')]
    @set view: new FilingView(model: @)
    unless @get('initialLoad')
      @alert()

  alert: ->
    return unless appSettings.get('showNotifications')
    unless window.webkitNotifications
      console.log 'No support for desktop notifications'

    if window.webkitNotifications.checkPermission() > 0
      @requestPermission(@alert)

    icon = 'http://query.nictusa.com/images/fec1.gif'
    popup = window.webkitNotifications.createNotification icon, @get('committee_name'), "#{@get('report_title')}#{if @get('is_amendment') then ('amendment')}"
    popup.show()

  requestPermission: (callback) ->
    window.webkitNotifications.requestPermission callback


class Filings extends Backbone.Collection

  model: Filing

  getFilings: (initialLoad=false) ->
    return unless appSettings.get('apikey').length > 0
    $.ajax
      dataType: 'jsonp'
      url: 'http://api.nytimes.com/svc/elections/us/v3/finances/2012/filings.json'
      data:
        'api-key': $("#apikey").val()
      success: (data) =>
        unless data.status is 'OK'
          throw new Error "Error. Status: #{data.status}"
        for result in data.results
          unless @get(result.fec_uri)
            result = _(result).extend
              id: result.fec_uri
              timestamp: new Date()
              initialLoad: initialLoad
            @add result
    setTimeout((=> @getFilings()), 900000)


class FilingView extends Backbone.View

  tagName: 'tr'

  initialize: ->
    @template = _.template $("#filing-row-template").html()
    @render()

  render: ->
    $(@el).html @template(@model.toJSON())
    $("#filings tbody").append @el


class Settings extends Backbone.Model

  defaults:
    apikey: ''
    showNotifications: false

  initialize: ->
    args = @getQs()
    if args.apikey?
      $("#apikey").val args.apikey
      @set apikey: args.apikey

    @set showNotifications: args.notify is 'true'

  getQs: ->
    qs = window.location.search.substring 1
    pairs = qs.split '&'
    args = {}
    for pair in pairs
      [k, v] = pair.split '='
      args[k] = unescape v
    args

  save: (callback) ->
    @set
      apikey: $("#apikey").val()
      showNotifications: $("#show-notifications").attr('checked') is 'checked'

    if @get('apikey').length > 0
      window.location.search = "?apikey=#{@get('apikey')}&notify=#{@get('showNotifications')}"

    filings.getFilings(true)


class SaveSettingsView extends Backbone.View

  el: "#save-settings"

  events:
    'click': 'handleClick'

  handleClick: (e) ->
    e.preventDefault()
    $("#settings").modal('hide')


$(document).ready ->
  filings = new Filings()
  appSettings = new Settings()

  filings.getFilings(true)

  if appSettings.get('apikey')
    $("#filing-content").show()
  else
    $("#welcome").show()

  $("#settings").on 'shown', ->
    saveSettingsView = new SaveSettingsView()
    if appSettings.get('showNotifications') is true
      $("#show-notifications").attr('checked', 'checked')

  $("#settings").on 'hide', ->
    appSettings.save()

  $("#update-now").bind 'click', ->
    filings.getFilings()

  $("#welcome-enter-api-key").bind 'click', ->
    $("#settings").modal('show')