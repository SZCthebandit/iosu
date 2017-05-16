//
//  BeatmapDecoder.swift
//  iosu
//
//  Created by xieyi on 2017/3/30.
//  Copyright © 2017年 xieyi. All rights reserved.
//

import Foundation
import UIKit

class Beatmap{
    
    public var bgimg:String = ""
    public var audiofile:String = ""
    public var difficulty:BMDifficulty?
    public var timingpoints:[TimingPoint] = []
    public var colors:[UIColor] = []
    public var hitobjects:[HitObject] = []
    public var sampleSet:SampleSet = .Auto //Set of audios
    public var bgvideos:[BGVideo]=[]
    public var widesb=false
    
    init(file:String) throws {
        debugPrint("full path: \(file)")
        let readFile=FileHandle(forReadingAtPath: file)
        if readFile===nil{
            throw BeatmapError.FileNotFound
        }
        let bmData=readFile?.readDataToEndOfFile()
        let bmString=String(data: bmData!, encoding: .utf8)
        let rawlines=bmString?.components(separatedBy: CharacterSet.newlines)
        if rawlines?.count==0{
            throw BeatmapError.IllegalFormat
        }
        var lines=ArraySlice<String>()
        for line in rawlines! {
            if line != "" {
                if !line.hasPrefix("//"){
                    lines.append(line)
                }
            }
        }
        var index:Int
        index = -1
        for line in lines{
            index += 1
            switch line {
            case "[General]":
                try parseGeneral(lines: lines.suffix(from: index+1))
                break
            case "[Difficulty]":
                parseDifficulty(lines: lines.suffix(from: index+1))
                break
            case "[Events]":
                parseEvents(lines: lines.suffix(from: index+1))
                break
            case "[TimingPoints]":
                try parseTimingPoints(lines: lines.suffix(from: index+1))
                break
            case "[Colours]":
                try parseColors(lines: lines.suffix(from: index+1))
                break
            case "[HitObjects]":
                try parseHitObjects(lines: lines.suffix(from: index+1))
                break
            default:
                continue
            }
        }
        bgvideos.sort(by: {(v1,v2)->Bool in
            return v1.time<v2.time
        })
    }
    
    func getTimingPoint(offset:Int) -> TimingPoint {
        for i in (0...timingpoints.count-1).reversed() {
            if timingpoints[i].offset <= offset {
                return timingpoints[i]
            }
        }
        return timingpoints[0]
    }
 
    func parseGeneral(lines:ArraySlice<String>) throws -> Void {
        for line in lines{
            if line.hasPrefix("["){
                if(audiofile==""){
                    throw BeatmapError.NoAudioFile
                }
                return
            }
            let splitted=line.components(separatedBy: ":")
            if splitted.count<=1{
                continue
            }
            var value=splitted[1] as NSString
            while value.substring(to: 1)==" "{
                value=value.substring(from: 1) as NSString
            }
            if value.length==0{
                throw BeatmapError.NoAudioFile
            }
            switch splitted[0] {
            case "AudioFilename":
                audiofile=value as String
                break
            case "SampleSet":
                sampleSet=samplesetConv(str: value as String)
                break
            case "WidescreenStoryboard":
                if (value as NSString).integerValue==1 {
                    debugPrint("Widescreen Storyboard enabled")
                    widesb=true
                }
                break
            default:break
            }
        }
    }
    
    func samplesetConv(str:String) -> SampleSet {
        switch str {
        case "Normal":
            return .Normal
        case "Soft":
            return .Soft
        case "Drum":
            return .Drum
        default:
            return .Auto
        }
    }
    
    func parseDifficulty(lines:ArraySlice<String>) -> Void {
        var hp:Double = -1
        var cs:Double = -1
        var od:Double = 5
        var ar:Double = -1
        var sm:Double = 1.4
        var st:Double = 1
        for line in lines{
            if line.hasPrefix("["){
                if(hp == -1){
                    hp=od
                }
                if(cs == -1){
                    cs=od
                }
                if(ar == -1){
                    ar=od
                }
                difficulty=BMDifficulty(HP: hp, CS: cs, OD: od, AR: ar, SM: sm, ST: st)
                return
            }
            let splitted=line.components(separatedBy: ":")
            if splitted.count != 2 {
                continue
            }
            let value=(splitted[1] as NSString).doubleValue
            switch splitted[0] {
            case "HPDrainRate":
                hp=value
                break
            case "CircleSize":
                cs=value
                break
            case "OverallDifficulty":
                od=value
                break
            case "ApproachRate":
                ar=value
                break
            case "SliderMultiplier":
                sm=value
                break
            case "SliderTickRate":
                st=value
                break
            default:
                break
            }
        }
        if(hp == -1){
            hp=od
        }
        if(cs == -1){
            cs=od
        }
        if(ar == -1){
            ar=od
        }
        difficulty=BMDifficulty(HP: hp, CS: cs, OD: od, AR: ar, SM: sm, ST: st)
    }
    
    func parseEvents(lines:ArraySlice<String>) -> Void {
        for line in lines {
            if line.hasPrefix("[") {
                return
            }
            if line.hasPrefix("Video") {
                let splitted=line.components(separatedBy: ",")
                var vstr=splitted[2]
                vstr=(vstr as NSString).replacingOccurrences(of: "\\", with: "/")
                while vstr.hasPrefix("\"") {
                    vstr=(vstr as NSString).substring(from: 1)
                }
                while vstr.hasSuffix("\"") {
                    vstr=(vstr as NSString).substring(to: vstr.lengthOfBytes(using: .ascii)-1)
                }
                bgvideos.append(BGVideo(file: vstr, time: (splitted[1] as NSString).integerValue))
                debugPrint("find video \(vstr) with offset \(bgvideos.last?.time)")
            } else {
                let splitted=line.components(separatedBy: ",")
                if splitted.count>=3 {
                    switch splitted[0] {
                    case "0":
                        var vstr=splitted[2]
                        vstr=(vstr as NSString).replacingOccurrences(of: "\\", with: "/")
                        while vstr.hasPrefix("\"") {
                            vstr=(vstr as NSString).substring(from: 1)
                        }
                        while vstr.hasSuffix("\"") {
                            vstr=(vstr as NSString).substring(to: vstr.lengthOfBytes(using: .ascii)-1)
                        }
                        bgimg=vstr
                        break
                    case "1":
                        var vstr=splitted[2]
                        vstr=(vstr as NSString).replacingOccurrences(of: "\\", with: "/")
                        while vstr.hasPrefix("\"") {
                            vstr=(vstr as NSString).substring(from: 1)
                        }
                        while vstr.hasSuffix("\"") {
                            vstr=(vstr as NSString).substring(to: vstr.lengthOfBytes(using: .ascii)-1)
                        }
                        bgvideos.append(BGVideo(file: vstr, time: (splitted[1] as NSString).integerValue))
                        break
                    default:
                        continue
                    }
                }
            }
        }
    }
    
    func parseTimingPoints(lines:ArraySlice<String>) throws -> Void {
        var lasttimeperbeat:Double = 0
        for line in lines{
            if line.hasPrefix("["){
                if(timingpoints.count==0){
                    throw BeatmapError.NoTimingPoints
                }
                return
            }
            var splitted=line.components(separatedBy: ",")
            if splitted.count<8 {
                if splitted.count==6 {
                    splitted.append("1")
                    splitted.append("0")
                } else if splitted.count==7 {
                    splitted.append("0")
                } else {
                    continue
                }
            }
            if splitted[6]=="1" { //Not inherited
                let offset=(splitted[0] as NSString).integerValue
                let timeperbeat=(splitted[1] as NSString).doubleValue
                let meter=(splitted[2] as NSString).integerValue
                let sampleset=samplesetConv(str: splitted[3])
                let samplesetid=(splitted[4] as NSString).integerValue
                let volume=(splitted[5] as NSString).integerValue
                let kiai=((splitted[7] as NSString).integerValue == 1)
                timingpoints.append(TimingPoint(offset: offset, timeperbeat: timeperbeat, beattype: meter, sampleset: sampleset, samplesetid: samplesetid, volume: volume, inherited: false, kiai: kiai))
                lasttimeperbeat=timeperbeat
            }else{ //Inherited
                let offset=(splitted[0] as NSString).integerValue
                let timeperbeat=(splitted[1] as NSString).doubleValue
                let meter=(splitted[2] as NSString).integerValue
                let sampleset=samplesetConv(str: splitted[3])
                let samplesetid=(splitted[4] as NSString).integerValue
                let volume=(splitted[5] as NSString).integerValue
                let kiai=((splitted[7] as NSString).integerValue == 1)
                timingpoints.append(TimingPoint(offset: offset, timeperbeat: lasttimeperbeat*abs(timeperbeat/100), beattype: meter, sampleset: sampleset, samplesetid: samplesetid, volume: volume, inherited: true, kiai: kiai))
            }
        }
    }
    
    func parseColors(lines:ArraySlice<String>) throws -> Void{
        for line in lines{
            if line.hasPrefix("["){
                if(colors.count==0){
                    throw BeatmapError.NoColor
                }
                return
            }
            let splitted=line.components(separatedBy: ":")
            if splitted.count==0{
                continue
            }
            if splitted[0].hasPrefix("Combo"){
                let dsplitted=splitted[1].components(separatedBy: ",")
                if dsplitted.count != 3{
                    throw BeatmapError.IllegalFormat
                }
                colors.append(UIColor(red: CGFloat((dsplitted[0] as NSString).floatValue/255), green: CGFloat((dsplitted[1] as NSString).floatValue/255), blue: CGFloat((dsplitted[2] as NSString).floatValue/255), alpha: 1.0))
            }
        }
    }
    
    func parseHitObjects(lines:ArraySlice<String>) throws -> Void {
        var newcombo=true
        for line in lines{
            if line.hasPrefix("["){
                if(hitobjects.count==0){
                    throw BeatmapError.NoHitObject
                }
                return
            }
            let splitted=line.components(separatedBy: ",")
            //debugPrint("\(splitted.count)")
            if splitted.count<5{
                continue
            }
            let typenum = (splitted[3] as NSString).integerValue % 16
            switch HitObject.getObjectType(num: typenum) {
            case .Circle:
                newcombo=newcombo || HitObject.getNewCombo(num: typenum)
                hitobjects.append(HitCircle(x: (splitted[0] as NSString).integerValue, y: (splitted[1] as NSString).integerValue, time: (splitted[2] as NSString).integerValue, hitsound: (splitted[4] as NSString).integerValue, newCombo: newcombo))
                newcombo=false
                break
            case .Slider:
                newcombo=newcombo || HitObject.getNewCombo(num: typenum)
                let dslider=decodeSlider(sliderinfo: splitted[5])
                let slider=Slider(x: (splitted[0] as NSString).integerValue, y: (splitted[1] as NSString).integerValue, slidertype: dslider.type, curveX: dslider.cx, curveY: dslider.cy, time: (splitted[2] as NSString).integerValue, hitsound: (splitted[4] as NSString).integerValue, newCombo: newcombo, repe: (splitted[6] as NSString).integerValue,length:(splitted[7] as NSString).integerValue)
                if(slider.time==19829){
                    slider.genpath(debug: true)
                }else{
                    slider.genpath(debug: false)
                }
                hitobjects.append(slider)
                break
            case .Spinner:
                newcombo=true //TODO: Maybe wrong
                hitobjects.append(Spinner(time: (splitted[2] as NSString).integerValue, hitsound: (splitted[4] as NSString).integerValue, endtime: (splitted[5] as NSString).integerValue, newcombo: newcombo))
                break
            case .None:
                continue
            }
        }
    }
    
    func decodeSlider(sliderinfo:String) -> DecodedSlider {
        let splitted=sliderinfo.components(separatedBy: "|")
        if splitted.count<=1{
            return DecodedSlider(cx: [], cy: [], type: .None)
        }
        var type=SliderType.None
        switch splitted[0]{
        case "L":
            type = .Linear
            break
        case "P":
            type = .PassThrough
            break
        case "B":
            type = .Bezier
            break
        case "C":
            type = .Catmull
            break
        default:
            return DecodedSlider(cx: [], cy: [], type: .None)
        }
        var cx:[Int] = []
        var cy:[Int] = []
        for i in 1...splitted.count-1 {
            let position=splitted[i].components(separatedBy: ":")
            if position.count != 2 {
                continue
            }
            let x=(position[0] as NSString).integerValue
            let y=(position[1] as NSString).integerValue
            cx.append(x)
            cy.append(y)
        }
        return DecodedSlider(cx: cx, cy: cy, type: type)
    }
    
    class DecodedSlider {
        
        public var cx:[Int]
        public var cy:[Int]
        public var type:SliderType
        
        init(cx:[Int],cy:[Int],type:SliderType) {
            self.cx=cx
            self.cy=cy
            self.type=type
        }
        
    }
    
}