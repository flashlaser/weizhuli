# -*- encoding : utf-8 -*-

# save my fans info snap
class GetTqqContentCountSnapTask < TqqTaskBase

  #  this task supported interval
  SUPPORT_INTERVAL = [:hourly,:daily,:weekly,:monthly]

  def run
    
    @time ||= Time.now
    @date = @time.to_date
    
    @interval_types.each{|interval_type|
      
      snap = snap_class(interval_type).new({:openid=>@openid})
      set_snap_time(snap, interval_type)


      # check the snap exist, if exist, just update
      last_snap = get_last_snap(interval_type)
      exist = snap.class.where({:openid=>@openid,:date=>snap.date}.merge( snap.respond_to?(:hour) ? {:hour=>snap.hour} : {})).first
      snap = exist if exist
      # end check
      muser = MTqqUser.where(:id=>@openid).first
      snap.statuses_count = muser.tweetnum

      case interval_type
        when :hourly
          now = @time || Time.now
          now = Time.local(now.year,now.month,now.day,now.hour)
          hour_ago = now-1.hour
          # TODO : 第一次执行时, 要将所有微博统计
          scope = TqqWeiboDetail.where(["openid = ? and post_at between ? and ?",@openid, hour_ago, now])
          
          snap.origin_count = scope.origins.count
          snap.forward_count = scope.forwards.count
          snap.video_count = scope.videos.count
          snap.image_count = scope.images.count
          snap.music_count = scope.musics.count
          snap.new_statuses_count = scope.count
          
          snap.be_forwarded_count = TqqForward.where(["openid = ? and forward_at between ? and ?",@openid, hour_ago, now]).count
          snap.be_commented_count = TqqComment.where(["openid = ? and comment_at between ? and ?",@openid, hour_ago, now]).count
          
        when :daily
          # get 24 hour's data for last day from hourly data
          yesterday = @date-1.day
          snap_stats = snap_class(:hourly).where(:openid=>@openid, :date=>yesterday).group("openid, date").select(group_sum_fields).first
          set_snap_fields(snap_stats, snap) if snap_stats
        when :weekly
          # get last 7 day's data from hourly data
          last_week = @date-1.week
          snap_stats = snap_class(:daily).where(["openid= ? and date >= ? and date < ?",@openid,last_week, @date]).group("openid").select(group_sum_fields).first
          set_snap_fields(snap_stats, snap) if snap_stats
        when :monthly
          # # get the data for last month from hourly data
          last_month = @date-1.month
          snap_stats = snap_class(:daily).where(["openid= ? and date >= ? and date < ?",@openid,last_month, @date]).group("openid").select(group_sum_fields).first
          set_snap_fields(snap_stats, snap) if snap_stats
          
      end
      snap.save! if snap.origin_count != nil
    }
  end
  
  
  def get_last_snap(interval_type)
    clazz = snap_class(interval_type)
    scope = clazz.where(["openid=?",@openid])
    scope = case interval_type
      when :hourly then scope.order("date desc, hour desc")
      else
        scope.order("date desc")
    end
    snap = scope.first
  end

  # set time for current stats (last date or last hour for hourly)
  def set_snap_time(snap,interval_type)
    t = case interval_type
      when :hourly then @time - 1.hour
      when :daily then @date - 1.day
      when :weekly then @date - 1.week
      when :monthly then @date - 1.month
    end
    snap.date = t.to_date
    snap.hour = t.hour if interval_type == :hourly
  end
  
  def snap_class(interval_type)
    ("TqqContentCountSnap"+interval_type.to_s.camelize).constantize
  end
  
  
  def group_sum_fields
    "sum(new_statuses_count) new_statuses_count, sum(be_forwarded_count) be_forwarded_count, sum(be_commented_count) be_commented_count, sum(forward_count) forward_count, sum(commented_count) commented_count, sum(image_count) image_count, sum(video_count) video_count, sum(music_count) music_count, sum(origin_count) origin_count"
  end
  
  def set_snap_fields(snap_stats, snap)
    snap.new_statuses_count  = snap_stats.new_statuses_count
    snap.be_forwarded_count  = snap_stats.be_forwarded_count
    snap.be_commented_count  = snap_stats.be_commented_count
    snap.forward_count  = snap_stats.forward_count
    snap.commented_count  = snap_stats.commented_count
    snap.image_count  = snap_stats.image_count
    snap.video_count  = snap_stats.video_count
    snap.music_count  = snap_stats.music_count
    snap.origin_count  = snap_stats.origin_count
  end
end

