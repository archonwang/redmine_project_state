require 'project_state/utils'

module ProjectStatePlugin
  module Reports
    include ProjectStatePlugin::Utilities

    # Labels for periods (date ranges), with identifying strings
    def ps_options_for_period
      return [[l(:label_last_12),"last_12"],
              [l(:label_last_6),"last_6"],
              [l(:label_last_3),"last_3"],
              [l(:label_this_year),"this_year"],
              [l(:label_last_year),"last_year"],
              [l(:label_this_fiscal),"this_fiscal"],
              [l(:label_last_fiscal),"last_fiscal"],
              [l(:label_this_quarter),"this_quarter"],
              [l(:label_last_quarter),"last_quarter"],
              [l(:label_this_month),"this_month"],
              [l(:label_last_month),"last_month"]]
    end

    # Labels for intervals ("by month" etc), with identifying strings
    def ps_options_for_interval
      return [[l(:label_by_month),"by_month"],
              [l(:label_by_week),"by_week"],
              [l(:label_by_quarter),"by_quarter"]]
    end

    # functions to calculate the beginning of a period, relative to today
    @@from_procs = {
      'last_12'      => proc { Date.today.beginning_of_month << 12 },
      'last_6'       => proc { Date.today.beginning_of_month << 6 },
      'last_3'       => proc { Date.today.beginning_of_month << 3 },
      'last_month'   => proc { Date.today.beginning_of_month << 1 },
      'this_month'   => proc { Date.today.beginning_of_month },
      'this_year'    => proc { Date.today.beginning_of_year },
      'last_year'    => proc { Date.today.beginning_of_year << 12 },
      'this_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                               Date.new(t.year+((t<apr)?(-1):0),4) },
      'last_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                               Date.new(t.year+((t<apr)?(-2):-1),4) },
      'this_quarter' => proc { Date.today.beginning_of_quarter },
      'last_quarter' => proc { Date.today.beginning_of_quarter << 3 },
    }
  
    # functions to calculate the end of a period, relative to today
    @@to_procs = {
      'last_12'      => proc { Date.today.beginning_of_month },
      'last_6'       => proc { Date.today.beginning_of_month },
      'last_3'       => proc { Date.today.beginning_of_month },
      'last_month'   => proc { Date.today.beginning_of_month },
      'this_month'   => proc { Date.today.end_of_month + 1 },
      'this_year'    => proc { Date.today.end_of_year + 1 },
      'last_year'    => proc { Date.today.beginning_of_year },
      'this_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                               Date.new(t.year+((t<apr)?0:1),4) },
      'last_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                               Date.new(t.year+((t<apr)?(-1):0),4) },
      'this_quarter' => proc { Date.today.end_of_quarter + 1 },
      'last_quarter' => proc { Date.today.beginning_of_quarter },
    }
  
    # functions to format a label for a period, e.g. "2015 Oct to 2016 Oct"
    @@label_procs = {
      'last_12'    => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'last_6'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'last_3'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'last_month' => proc { |x,_| "#{x.strftime('%Y %b')}" },
      'this_month' => proc { |x,_| "#{x.strftime('%Y %b')}" },
      'last_year' => proc { |x,_| "#{x.strftime('%Y')}" },
      'this_year' => proc { |x,_| "#{x.strftime('%Y')}" },
      'last_fiscal' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'this_fiscal' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'last_quarter' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
      'this_quarter' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    }
  
    # Given params from a web form, calculate the actual dates for the beginning
    # and end of the period.  "update" is true if we want to do the calculation.
    # Otherwise we just set the flags and labels and return.  (Strange, but keeps
    # other code simpler... fewer special cases.)
    # 
    # Function sets 3 instance variables:
    #   @from -- the start date
    #   @to -- the end date
    #   @intervaltitle -- a label for the period
    # Returns
    #   true if no errors; false otherwise
    #
    def set_up_time(params,update)
      okay = true
      if update
        if ! params.has_key? "date_type"
          flash[:warning] = l(:report_choose_radio_button)
          okay = false
        elsif params['date_type'] == '1'
          # One of the pre-defined ranges
          @to = @@to_procs[params['period_type']].call
          @from = @@from_procs[params['period_type']].call
          @intervaltitle = @@label_procs[params['period_type']].call(@from,@to)
          if okay
            params['report_date_to'] = "%s" % @to
            params['report_date_from'] = "%s" % @from
          end
        elsif params['date_type'] == '2'
          # a user-specified start and end date
          begin
            if !params.has_key?('report_date_from') || params['report_date_from'].blank?
              flash[:warning] = l(:report_choose_from_date)
              okay = false
            else
              @from = Date.parse(params['report_date_from'])
            end
            if !params.has_key?('report_date_to') || params['report_date_to'].blank?
              flash[:notice] = l(:report_choose_to_date)
              @to = Date.today
            else
              @to = Date.parse(params['report_date_to'])
            end
            if okay
              @intervaltitle = "#{@from.strftime('%Y %b %-d')} to #{@to.strftime('%Y %b %-d')}"
            end
          rescue ArgumentError
            flash[:error] = l(:report_date_format_error)
            okay = false
          end
        else
          $pslog.error("Unexpected date type '#{date_type}'")
          flash[:error] = l(:report_bad_date_type,:datetype => params['date_type'])
          okay = false
        end
      end
      @periods = ps_options_for_period
      @intervals = ps_options_for_interval
      return okay
    end
  
    # For report types that only offer a choice among the last 12 months (up to
    # the beginning of this month), this  convenience function sets up the
    # labels.
    def set_up_months(params,update)
      tod = Date.today
      @fin_list = (0..11).each.map do |i|
        m = tod << i
        tag = "#{Date::ABBR_MONTHNAMES[m.month]}-#{m.strftime("%Y")}"
      end
    end
  
    # Given @from and @to, and the interval type ("by month" etc),
    # construct a list of date ranges for which to report something.
    # Ranges are half-open: they start on the start date, and end
    # just before the end date.
    #
    # Uses the instance variables @from, @to, @params['interval_type']
    #
    # Sets the instance variable "@ends", containing the endponts of the
    # intervals, and @labels for each interval.  Doesn't set @start, because
    # it's just @ends[current-1] (with a special case for the first
    # interval, which starts at @from.
    def make_intervals
      current = @from
      @ends = []
      @labels = []
      okay = true
      real_to = [@to,Date.today].min
      case @params['interval_type']
      when 'by_month'
        while current < real_to
          @labels << Date::ABBR_MONTHNAMES[current.month]
          current = current >> 1
          @ends << current
        end
        @interval_label = 'month'
      when 'by_week'
        current = current.beginning_of_week
        @from = current
        while current < (real_to - 7)
          lweek = current + 6
          @labels << "W#{lweek.cweek}, #{Date::ABBR_MONTHNAMES[lweek.month]} #{lweek.day}"
          current = current + 7
          @ends << current
        end
        @interval_label = 'week'
      when 'by_quarter'
        while current < real_to
          q = ((current.month - 1) / 3)
          q = 4 if q == 0
          @labels << "Q#{q}"
          current = current >> 3
          @ends << current
        end
        @interval_label = 'quarter'
      else
        okay = false
        $pslog.error{"Unknown interval range '#{@params['interval_type']}'"}
        flash[:error] = l(:report_bad_interval_type,:inttype => params['interval_type'])
      end
      return okay
    end

    # Generate
    def time_waiting_data()
      @projects = {}
      projlist = collectProjects(Setting.plugin_project_state['billable'])
      Project.where(id: projlist).each do |proj|
        @projects[proj.id] = proj
      end
      state_prop_key = CustomField.find_by(name: 'Project State').id.to_s
      interesting = ["Ready","Hold"]
      start = @from
      rlist = []
      hlist = []
      @ready = []
      @hold = []
      @ends.each do |fin|
        Journal.where(created_on: start..(fin-1)).includes(:details).each do |j|
          iss = j.issue
          next unless @projects.include? iss.project_id
          j.details.each do |jd|
            if jd.property == 'cf' && jd.prop_key == state_prop_key && interesting.include?(jd.old_value)
              # it's a candidate
              prev = find_previous_change(j.issue,j.created_on,state_prop_key)
              interval = ((j.created_on - prev).to_i / 86400.0).round(2)
  #            $pslog.debug("Iss: #{iss.id} [#{jd.old_value}] -- From: #{prev}  To: #{j.created_on}  Interval: #{interval}")
  #            $pslog.debug("From: #{prev.class}  To: #{j.created_on.class}  Interval: #{interval.class}")
              if jd.old_value == 'Ready'
                rlist << interval
              else
                hlist << interval
              end
            end
          end
        end
        @ready << boxplot_values(rlist)
        @hold << boxplot_values(hlist)
        rlist = []
        hlist = []
        start = fin
      end
      @make_plot = true
    end
  
  
  end
end