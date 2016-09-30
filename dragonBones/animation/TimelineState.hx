package dragonBones.animation;

import openfl.geom.ColorTransform;
import openfl.geom.Point;

import dragonBones.Armature;
import dragonBones.Bone;
import dragonBones.Slot;
import dragonBones.objects.DBTransform;
import dragonBones.objects.Frame;
import dragonBones.objects.TimelineCached;
import dragonBones.objects.TransformFrame;
import dragonBones.objects.TransformTimeline;
import dragonBones.utils.TransformUtil;

/** @private */
class TimelineState
{
	private static var HALF_PI:Float = Math.PI * 0.5;
	private static var DOUBLE_PI:Float = Math.PI * 2;

	private static var _pool:Array<TimelineState> = new Array<TimelineState>();

	/** @private */
	public static function borrowObject():TimelineState
	{
		if(_pool.length == 0)
		{
			return new TimelineState();
		}
		return _pool.pop();
	}

	/** @private */
	public static function returnObject(timeline:TimelineState):Void
	{
		if(_pool.indexOf(timeline) < 0)
		{
			_pool.push(timeline);
		}

		timeline.clear();
	}

	/** @private */
	public static function clearPool():Void
	{
		var i:Int = _pool.length;
		while(i -- > 0)
		{
			_pool[i].clear();
		}
		_pool = new Array<TimelineState>();
	}

	/** @private */
	public static function getEaseValue(value:Float, easing:Float):Float
    {
		var valueEase:Float = 1;
		if(easing > 1)    //ease in out
		{
			valueEase = 0.5 * (1 - Math.cos(value * Math.PI));
			easing -= 1;
		}
		else if (easing > 0)    //ease out
		{
			valueEase = 1 - Math.pow(1-value,2);
		}
		else if (easing < 0)    //ease in
		{
			easing *= -1;
			valueEase =  Math.pow(value,2);
		}

		return (valueEase - value) * easing + value;
    }

	/** @private */
	public var _weight:Float;

	/** @private */
	public var _transform:DBTransform;

	/** @private */
	public var _pivot:Point;

	/** @private */
	public var _blendEnabled:Bool;

	/** @private */
	public var _isComplete:Bool;

	/** @private */
	public var _animationState:AnimationState;

	private var _totalTime:Int;
	private var _currentTime:Int;
	private var _currentFrameIndex:Int;
	private var _currentFramePosition:Int;
	private var _currentFrameDuration:Int;
	private var _tweenEasing:Float;
	private var _tweenTransform:Bool;
	private var _tweenScale:Bool;
	private var _tweenColor:Bool;
	private var _rawAnimationScale:Float;
	private var _updateState:Int;

	private var _armature:Armature;
	private var _animation:Animation;
	private var _bone:Bone;
	private var _timeline:TransformTimeline;
	private var _originTransform:DBTransform;
	private var _originPivot:Point;

	private var _durationTransform:DBTransform;
	private var _durationPivot:Point;
	private var _durationColor:ColorTransform;

	public var name:String;

	public function new()
	{
		_transform = new DBTransform();
		_pivot = new Point();

		_durationTransform = new DBTransform();
		_durationPivot = new Point();
		_durationColor = new ColorTransform();
	}

	/** @private */
	public function fadeIn(bone:Bone, animationState:AnimationState, timeline:TransformTimeline):Void
	{
		_bone = bone;
		_armature = _bone.armature;
		_animation = _armature.animation;
		_animationState = animationState;
		_timeline = timeline;
		_originTransform = _timeline.originTransform;
		_originPivot = _timeline.originPivot;

		name = _timeline.name;

		_totalTime = _timeline.duration;
		_rawAnimationScale = _animationState.clip.scale;

		_isComplete = false;
		_blendEnabled = false;
		_tweenTransform = false;
		_tweenScale = false;
		_tweenColor = false;
		_currentFrameIndex = -1;
		_currentTime = -1;
		_tweenEasing = Math.NaN;
		_weight = 1;

		_transform.x = 0;
		_transform.y = 0;
		_transform.scaleX = 1;
		_transform.scaleY = 1;
		_transform.skewX = 0;
		_transform.skewY = 0;
		_pivot.x = 0;
		_pivot.y = 0;

		_durationTransform.x = 0;
		_durationTransform.y = 0;
		_durationTransform.scaleX = 1;
		_durationTransform.scaleY = 1;
		_durationTransform.skewX = 0;
		_durationTransform.skewY = 0;
		_durationPivot.x = 0;
		_durationPivot.y = 0;

		switch(_timeline.frameList.length)
		{
			case 0:
				_updateState = 0;

			case 1:
				_updateState = -1;

			default:
				_updateState = 1;
		}

		_bone.addState(this);
	}

	/** @private */
	public function fadeOut():Void
	{
		_transform.skewX = TransformUtil.formatRadian(_transform.skewX);
		_transform.skewY = TransformUtil.formatRadian(_transform.skewY);
	}

	/** @private */
	public function update(progress:Float):Void
	{
		if(_updateState > 0)
		{
			updateMultipleFrame(progress);
		}
		else if(_updateState < 0)
		{
			_updateState = 0;
			updateSingleFrame();
		}
	}

	private function updateMultipleFrame(progress:Float):Void
	{
		var currentPlayTimes:Int = 0;
		progress /= _timeline.scale;
		progress += _timeline.offset;

		var currentTime:Int = Std.int(_totalTime * progress);
		var playTimes:Int = _animationState.playTimes;
		if(playTimes == 0)
		{
			_isComplete = false;
			currentPlayTimes = Math.ceil(Math.abs(currentTime) / _totalTime);
			if (currentPlayTimes == 0) {
				currentPlayTimes = 1;
			}
			//currentTime -= Math.floor(currentTime / _totalTime) * _totalTime;
			currentTime -= Std.int((currentTime / _totalTime)) * _totalTime; // TODO

			if(currentTime < 0)
			{
				currentTime += _totalTime;
			}
		}
		else
		{
			var totalTimes:Int = playTimes * _totalTime;
			if(currentTime >= totalTimes)
			{
				currentTime = totalTimes;
				_isComplete = true;
			}
			else if(currentTime <= -totalTimes)
			{
				currentTime = -totalTimes;
				_isComplete = true;
			}
			else
			{
				_isComplete = false;
			}

			if(currentTime < 0)
			{
				currentTime += totalTimes;
			}

			currentPlayTimes = Math.ceil(currentTime / _totalTime);
			if (currentPlayTimes == 0) {
				currentPlayTimes = 1;
			}
			if(_isComplete)
			{
				currentTime = _totalTime;
			}
			else
			{
				//currentTime -= Math.floor(currentTime / _totalTime) * _totalTime;
				currentTime -= Std.int(currentTime / _totalTime) * _totalTime;
			}
		}

		if(_currentTime != currentTime && _timeline.frameList != null)
		{
			_currentTime = currentTime;

			var frameList:Array<Frame> = _timeline.frameList;
			var prevFrame:TransformFrame = null;
			var currentFrame:TransformFrame = null;

			for (i in 0..._timeline.frameList.length)
			{
				if(_currentFrameIndex < 0)
				{
					_currentFrameIndex = 0;
				}
				else if(_currentTime < _currentFramePosition || _currentTime >= _currentFramePosition + _currentFrameDuration)
				{
					_currentFrameIndex ++;
					if(_currentFrameIndex >= frameList.length)
					{
						if(_isComplete)
						{
							_currentFrameIndex --;
							break;
						}
						else
						{
							_currentFrameIndex = 0;
						}
					}
				}
				else
				{
					break;
				}
				currentFrame = cast(frameList[_currentFrameIndex], TransformFrame);

				if(prevFrame != null)
				{
					_bone.arriveAtFrame(prevFrame, this, _animationState, true);
				}

				_currentFrameDuration = currentFrame.duration;
				_currentFramePosition = currentFrame.position;
				prevFrame = currentFrame;
			}

			if(currentFrame != null)
			{
				_bone.arriveAtFrame(currentFrame, this, _animationState, false);

				_blendEnabled = currentFrame.displayIndex >= 0;
				if(_blendEnabled)
				{
					updateToNextFrame(currentPlayTimes);
				}
				else
				{
					_tweenEasing = Math.NaN;
					_tweenTransform = false;
					_tweenScale = false;
					_tweenColor = false;
				}
			}

			if(_blendEnabled)
			{
				updateTween();
			}
		}
	}

	private function updateToNextFrame(currentPlayTimes:Int):Void
	{
		var nextFrameIndex:Int = _currentFrameIndex + 1;
		if(nextFrameIndex >= _timeline.frameList.length)
		{
			nextFrameIndex = 0;
		}
		var currentFrame:TransformFrame = cast(_timeline.frameList[_currentFrameIndex], TransformFrame);
		var nextFrame:TransformFrame = cast(_timeline.frameList[nextFrameIndex], TransformFrame);
		var tweenEnabled:Bool = false;
		if(
			nextFrameIndex == 0 &&
			(
				!_animationState.lastFrameAutoTween ||
				(
					_animationState.playTimes != 0 &&
					_animationState.currentPlayTimes >= _animationState.playTimes &&
					((_currentFramePosition + _currentFrameDuration) / _totalTime + currentPlayTimes - _timeline.offset) * _timeline.scale > 0.999999
				)
			)
		)
		{
			_tweenEasing = Math.NaN;
			tweenEnabled = false;
		}
		else if(currentFrame.displayIndex < 0 || nextFrame.displayIndex < 0)
		{
			_tweenEasing = Math.NaN;
			tweenEnabled = false;
		}
		else if(_animationState.autoTween)
		{
			_tweenEasing = _animationState.clip.tweenEasing;
			if(Math.isNaN(_tweenEasing))
			{
				_tweenEasing = currentFrame.tweenEasing;
				if(Math.isNaN(_tweenEasing))    //frame no tween
				{
					tweenEnabled = false;
				}
				else
				{
					if(_tweenEasing == 10)
					{
						_tweenEasing = 0;
					}
					//_tweenEasing [-1, 0) 0 (0, 1] (1, 2]
					tweenEnabled = true;
				}
			}
			else    //animationData overwrite tween
			{
				//_tweenEasing [-1, 0) 0 (0, 1] (1, 2]
				tweenEnabled = true;
			}
		}
		else
		{
			_tweenEasing = currentFrame.tweenEasing;
			if(Math.isNaN(_tweenEasing) || _tweenEasing == 10)    //frame no tween
			{
				_tweenEasing = Math.NaN;
				tweenEnabled = false;
			}
			else
			{
				//_tweenEasing [-1, 0) 0 (0, 1] (1, 2]
				tweenEnabled = true;
			}
		}

		if(tweenEnabled)
		{
			//transform
			_durationTransform.x = nextFrame.transform.x - currentFrame.transform.x;
			_durationTransform.y = nextFrame.transform.y - currentFrame.transform.y;
			_durationTransform.skewX = nextFrame.transform.skewX - currentFrame.transform.skewX;
			_durationTransform.skewY = nextFrame.transform.skewY - currentFrame.transform.skewY;

			/*
			_durationTransform.scaleX = nextFrame.transform.scaleX - currentFrame.transform.scaleX;
			_durationTransform.scaleY = nextFrame.transform.scaleY - currentFrame.transform.scaleY;
			*/

			_durationTransform.scaleX = nextFrame.transform.scaleX - currentFrame.transform.scaleX + nextFrame.scaleOffset.x;
			_durationTransform.scaleY = nextFrame.transform.scaleY - currentFrame.transform.scaleY + nextFrame.scaleOffset.y;

			if(nextFrameIndex == 0)
			{
				_durationTransform.skewX = TransformUtil.formatRadian(_durationTransform.skewX);
				_durationTransform.skewY = TransformUtil.formatRadian(_durationTransform.skewY);
			}

			_durationPivot.x = nextFrame.pivot.x - currentFrame.pivot.x;
			_durationPivot.y = nextFrame.pivot.y - currentFrame.pivot.y;

			if(
				_durationTransform.x != 0 ||
				_durationTransform.y  != 0 ||
				_durationTransform.skewX != 0 ||
				_durationTransform.skewY != 0 ||
				_durationTransform.scaleX != 0 ||
				_durationTransform.scaleY != 0 ||
				_durationPivot.x != 0 ||
				_durationPivot.y != 0
			)
			{
				_tweenTransform = true;
				_tweenScale = currentFrame.tweenScale;
			}
			else
			{
				_tweenTransform = false;
				_tweenScale = false;
			}

			//color
			if(currentFrame.color != null && nextFrame.color != null)
			{
				_durationColor.alphaOffset = nextFrame.color.alphaOffset - currentFrame.color.alphaOffset;
				_durationColor.redOffset = nextFrame.color.redOffset - currentFrame.color.redOffset;
				_durationColor.greenOffset = nextFrame.color.greenOffset - currentFrame.color.greenOffset;
				_durationColor.blueOffset = nextFrame.color.blueOffset - currentFrame.color.blueOffset;

				_durationColor.alphaMultiplier = nextFrame.color.alphaMultiplier - currentFrame.color.alphaMultiplier;
				_durationColor.redMultiplier = nextFrame.color.redMultiplier - currentFrame.color.redMultiplier;
				_durationColor.greenMultiplier = nextFrame.color.greenMultiplier - currentFrame.color.greenMultiplier;
				_durationColor.blueMultiplier = nextFrame.color.blueMultiplier - currentFrame.color.blueMultiplier;

				if(
					_durationColor.alphaOffset != 0 ||
					_durationColor.redOffset != 0 ||
					_durationColor.greenOffset != 0 ||
					_durationColor.blueOffset != 0 ||
					_durationColor.alphaMultiplier != 0 ||
					_durationColor.redMultiplier != 0 ||
					_durationColor.greenMultiplier != 0 ||
					_durationColor.blueMultiplier != 0
				)
				{
					_tweenColor = true;
				}
				else
				{
					_tweenColor = false;
				}
			}
			else if(currentFrame.color != null)
			{
				_tweenColor = true;
				_durationColor.alphaOffset = -currentFrame.color.alphaOffset;
				_durationColor.redOffset = -currentFrame.color.redOffset;
				_durationColor.greenOffset = -currentFrame.color.greenOffset;
				_durationColor.blueOffset = -currentFrame.color.blueOffset;

				_durationColor.alphaMultiplier = 1 - currentFrame.color.alphaMultiplier;
				_durationColor.redMultiplier = 1 - currentFrame.color.redMultiplier;
				_durationColor.greenMultiplier = 1 - currentFrame.color.greenMultiplier;
				_durationColor.blueMultiplier = 1 - currentFrame.color.blueMultiplier;
			}
			else if(nextFrame.color != null)
			{
				_tweenColor = true;
				_durationColor.alphaOffset = nextFrame.color.alphaOffset;
				_durationColor.redOffset = nextFrame.color.redOffset;
				_durationColor.greenOffset = nextFrame.color.greenOffset;
				_durationColor.blueOffset = nextFrame.color.blueOffset;

				_durationColor.alphaMultiplier = nextFrame.color.alphaMultiplier - 1;
				_durationColor.redMultiplier = nextFrame.color.redMultiplier - 1;
				_durationColor.greenMultiplier = nextFrame.color.greenMultiplier - 1;
				_durationColor.blueMultiplier = nextFrame.color.blueMultiplier - 1;
			}
			else
			{
				_tweenColor = false;
			}
		}
		else
		{
			_tweenTransform = false;
			_tweenScale = false;
			_tweenColor = false;
		}

		if(!_tweenTransform)
		{
			if(!updateTimelineCached(true))
			{
				if(_animationState.additiveBlending)
				{
					_transform.x = currentFrame.transform.x;
					_transform.y = currentFrame.transform.y;
					_transform.skewX = currentFrame.transform.skewX;
					_transform.skewY = currentFrame.transform.skewY;
					_transform.scaleX = currentFrame.transform.scaleX;
					_transform.scaleY = currentFrame.transform.scaleY;

					_pivot.x = currentFrame.pivot.x;
					_pivot.y = currentFrame.pivot.y;
				}
				else
				{
					_transform.x = _originTransform.x + currentFrame.transform.x;
					_transform.y = _originTransform.y + currentFrame.transform.y;
					_transform.skewX = _originTransform.skewX + currentFrame.transform.skewX;
					_transform.skewY = _originTransform.skewY + currentFrame.transform.skewY;
					_transform.scaleX = _originTransform.scaleX * currentFrame.transform.scaleX;
					_transform.scaleY = _originTransform.scaleY * currentFrame.transform.scaleY;

					_pivot.x = _originPivot.x + currentFrame.pivot.x;
					_pivot.y = _originPivot.y + currentFrame.pivot.y;
				}
			}

			_bone.invalidUpdate();
		}
		else if(!_tweenScale)
		{
			if(_animationState.additiveBlending)
			{
				_transform.scaleX = currentFrame.transform.scaleX;
				_transform.scaleY = currentFrame.transform.scaleY;
			}
			else
			{
				_transform.scaleX = _originTransform.scaleX * currentFrame.transform.scaleX;
				_transform.scaleY = _originTransform.scaleY * currentFrame.transform.scaleY;
			}
		}

		if(!_tweenColor && _animationState.displayControl)
		{
			if(currentFrame.color != null)
			{
				_bone.updateColor(
					currentFrame.color.alphaOffset,
					currentFrame.color.redOffset,
					currentFrame.color.greenOffset,
					currentFrame.color.blueOffset,
					currentFrame.color.alphaMultiplier,
					currentFrame.color.redMultiplier,
					currentFrame.color.greenMultiplier,
					currentFrame.color.blueMultiplier,
					true
				);
			}
			else if(_bone._isColorChanged)
			{
				_bone.updateColor(0, 0, 0, 0, 1, 1, 1, 1, false);
			}

		}
	}

	private function updateTween():Void
	{
		var progress:Float = (_currentTime - _currentFramePosition) / _currentFrameDuration;
		if(_tweenEasing != 0)
		{
			progress = getEaseValue(progress, _tweenEasing);
		}

		var currentFrame:TransformFrame = cast(_timeline.frameList[_currentFrameIndex], TransformFrame);
		if(_tweenTransform)
		{
			if(!updateTimelineCached(false))
			{
				var currentTransform:DBTransform = currentFrame.transform;
				var currentPivot:Point = currentFrame.pivot;
				if(_animationState.additiveBlending)
				{
					//additive blending
					_transform.x = currentTransform.x + _durationTransform.x * progress;
					_transform.y = currentTransform.y + _durationTransform.y * progress;
					_transform.skewX = currentTransform.skewX + _durationTransform.skewX * progress;
					_transform.skewY = currentTransform.skewY + _durationTransform.skewY * progress;
					if(_tweenScale)
					{
						_transform.scaleX = currentTransform.scaleX + _durationTransform.scaleX * progress;
						_transform.scaleY = currentTransform.scaleY + _durationTransform.scaleY * progress;
					}

					_pivot.x = currentPivot.x + _durationPivot.x * progress;
					_pivot.y = currentPivot.y + _durationPivot.y * progress;
				}
				else
				{
					//normal blending
					_transform.x = _originTransform.x + currentTransform.x + _durationTransform.x * progress;
					_transform.y = _originTransform.y + currentTransform.y + _durationTransform.y * progress;
					_transform.skewX = _originTransform.skewX + currentTransform.skewX + _durationTransform.skewX * progress;
					_transform.skewY = _originTransform.skewY + currentTransform.skewY + _durationTransform.skewY * progress;
					if(_tweenScale)
					{
						_transform.scaleX = _originTransform.scaleX * currentTransform.scaleX + _durationTransform.scaleX * progress;
						_transform.scaleY = _originTransform.scaleY * currentTransform.scaleY + _durationTransform.scaleY * progress;
					}

					_pivot.x = _originPivot.x + currentPivot.x + _durationPivot.x * progress;
					_pivot.y = _originPivot.y + currentPivot.y + _durationPivot.y * progress;
				}
			}

			_bone.invalidUpdate();
		}

		if(_tweenColor && _animationState.displayControl)
		{
			if(currentFrame.color != null)
			{
				_bone.updateColor(
					currentFrame.color.alphaOffset + _durationColor.alphaOffset * progress,
					currentFrame.color.redOffset + _durationColor.redOffset * progress,
					currentFrame.color.greenOffset + _durationColor.greenOffset * progress,
					currentFrame.color.blueOffset + _durationColor.blueOffset * progress,
					currentFrame.color.alphaMultiplier + _durationColor.alphaMultiplier * progress,
					currentFrame.color.redMultiplier + _durationColor.redMultiplier * progress,
					currentFrame.color.greenMultiplier + _durationColor.greenMultiplier * progress,
					currentFrame.color.blueMultiplier + _durationColor.blueMultiplier * progress,
					true
				);
			}
			else
			{
				_bone.updateColor(
					_durationColor.alphaOffset * progress,
					_durationColor.redOffset * progress,
					_durationColor.greenOffset * progress,
					_durationColor.blueOffset * progress,
					1 + _durationColor.alphaMultiplier * progress,
					1 + _durationColor.redMultiplier * progress,
					1 + _durationColor.greenMultiplier * progress,
					1 + _durationColor.blueMultiplier * progress,
					true
				);
			}
		}
	}

	private function updateTimelineCached(isNoTweenFrame:Bool):Bool
	{
		var slot:Slot;
		var isCachedFrame:Bool = false;
		if(
			_armature.cacheFrameRate > 0 &&
			_animation._animationStateCount < 2 &&
			!_animation._isFading
		)
		{
			var timelineCached:TimelineCached = _timeline.timelineCached;
			if(_bone._timelineCached == null)
			{
				_bone._timelineCached = timelineCached;
				for (slot in _bone.getSlots(false))
				{
					slot._timelineCached = _timeline.getSlotTimelineCached(slot.name);
				}
			}
			//Math.floor
			var framePosition:Int = Std.int((isNoTweenFrame?_currentFramePosition:_currentTime) * 0.001 * _rawAnimationScale * _armature.cacheFrameRate);
			_bone._frameCachedPosition = framePosition;
			if(timelineCached.getFrame(framePosition) != null)
			{
				isCachedFrame = true;
				_bone._frameCachedDuration = -1;
			}
			else
			{
				_bone._frameCachedDuration = Std.int(isNoTweenFrame?Math.min(_currentFrameDuration * 0.001 * _rawAnimationScale * _armature.cacheFrameRate, 1):1);
			}
		}
		else if(_bone._timelineCached != null)
		{
			_bone._timelineCached = null;
			for (slot in _bone.getSlots(false))
			{
				slot._timelineCached = null;
			}
			_bone._frameCachedPosition = -1;
			_bone._frameCachedDuration = -1;
		}

		return isCachedFrame;
	}

	private function updateSingleFrame():Void
	{
		var currentFrame:TransformFrame = cast(_timeline.frameList[0], TransformFrame);
		_bone.arriveAtFrame(currentFrame, this, _animationState, false);
		_isComplete = true;
		_tweenEasing = Math.NaN;
		_tweenTransform = false;
		_tweenScale = false;
		_tweenColor = false;

		_blendEnabled = currentFrame.displayIndex >= 0;
		if(_blendEnabled)
		{
			/**
			 * <使用绝对数据>
			 * 单帧的timeline，第一个关键帧的transform为0
			 * timeline.originTransform = firstFrame.transform;
			 * eachFrame.transform = eachFrame.transform - timeline.originTransform;
			 * firstFrame.transform == 0;
			 *
			 * <使用相对数据>
			 * 使用相对数据时，timeline.originTransform = 0，第一个关键帧的transform有可能不为 0
			 */

			if(_animationState.additiveBlending)
			{
				_transform.x = currentFrame.transform.x;
				_transform.y = currentFrame.transform.y;
				_transform.skewX = currentFrame.transform.skewX;
				_transform.skewY = currentFrame.transform.skewY;
				_transform.scaleX = currentFrame.transform.scaleX;
				_transform.scaleY = currentFrame.transform.scaleY;

				_pivot.x = currentFrame.pivot.x;
				_pivot.y = currentFrame.pivot.y;
			}
			else
			{
				_transform.x = _originTransform.x + currentFrame.transform.x;
				_transform.y = _originTransform.y + currentFrame.transform.y;
				_transform.skewX = _originTransform.skewX + currentFrame.transform.skewX;
				_transform.skewY = _originTransform.skewY + currentFrame.transform.skewY;
				_transform.scaleX = _originTransform.scaleX * currentFrame.transform.scaleX;
				_transform.scaleY = _originTransform.scaleY * currentFrame.transform.scaleY;

				_pivot.x = _originPivot.x + currentFrame.pivot.x;
				_pivot.y = _originPivot.y + currentFrame.pivot.y;
			}


			_bone.invalidUpdate();

			if(_animationState.displayControl)
			{
				if(currentFrame.color != null)
				{
					_bone.updateColor(
						currentFrame.color.alphaOffset,
						currentFrame.color.redOffset,
						currentFrame.color.greenOffset,
						currentFrame.color.blueOffset,
						currentFrame.color.alphaMultiplier,
						currentFrame.color.redMultiplier,
						currentFrame.color.greenMultiplier,
						currentFrame.color.blueMultiplier,
						true
					);
				}
				else if(_bone._isColorChanged)
				{
					_bone.updateColor(0, 0, 0, 0, 1, 1, 1, 1, false);
				}
			}
		}
	}

	private function clear():Void
	{
		if(_bone != null)
		{
			_bone.removeState(this);
			_bone = null;
		}
		_armature = null;
		_animation = null;
		_animationState = null;
		_timeline = null;
		_originTransform = null;
		_originPivot = null;
	}
}
