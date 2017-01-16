//
//  ViewController.swift
//  BeaconSample
//
//  Created by T.S on 2017/01/14.
//  Copyright © 2017年 Takami. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

//ビーコンからThresh(m)離れた場合、地図上にピン(自転車の位置）が設置される
var Thresh = 3.0

//GPSが現在地を取得する頻度(2を指定した場合、2m移動するごとに現在地を取得する）
var dFilter = 1

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate{
    
    //CoreLocation 
    var locationManager:CLLocationManager!
    var beaconRegion:CLBeaconRegion!
    var uuid:NSUUID!
    var major:NSNumber = -1;
    var minor:NSNumber = -1;
    
    //距離測定
    var isBeaconRanging:Bool = false
    
    //MapView
    var mapView:MKMapView!
    var targetPin:MKPointAnnotation? = nil
    var timerObj:Timer!
    
    //緯度・経度
    var longitude:CLLocationDegrees!
    var latitude:CLLocationDegrees!
    
    //ピン
    var pin:MKPointAnnotation!
    
    //ピンと現在地までのライン
    var line:MKPolyline!
    var route: MKRoute!
    
    //ビーコンからの距離が閾値以内か否か
    var insideThresh = true
    
    //ラベル
    var statusLabel:UILabel!    //ビーコン領域の中(Inside)外(Outside)測定不可(Unknown)
    var threshLabel:UILabel!    //閾値
    var accuracyLabel:UILabel!   //ビーコンからの距離(m)
    
    
    //画面読み込み時に呼ばれるメソッド
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //CLLocationManagerオブジェクトの作成
        locationManager = CLLocationManager()
        
        //デリゲートを自身に設定
        locationManager.delegate = self
        
        //ビーコン領域の初期化
        self.beaconRegion = CLBeaconRegion(proximityUUID: UUID(uuidString:"B9407F30-F5F8-466E-AFF9-25556B57FE6D")!, identifier: "beacon")
        
        //画面が表示されいないときにも通知する
        self.beaconRegion.notifyEntryStateOnDisplay = false
        
        //ビーコン領域に入ったとき、出たときを通知する
        self.beaconRegion.notifyOnEntry = true
        self.beaconRegion.notifyOnExit = true
        
        self.isBeaconRanging = false
        
        //位置情報の認証のステータスを取得
        let status = CLLocationManager.authorizationStatus()
        //許可が得られていない場合
        if(status == CLAuthorizationStatus.notDetermined){
            if #available(iOS 8.0, *){
                self.locationManager.requestAlwaysAuthorization()
            }
        }
        
        //画面の初期化
        self.title = "ビーコン受信+MAP"
        
        //MapViewの生成
        mapView = MKMapView()
        
        //MapViewのサイズを画面全体に
        mapView.frame = self.view.bounds
        
        //ピンの初期化
        self.pin = MKPointAnnotation()
        
        //Delegateを設定
        mapView.delegate = self
        
        //MapViewをViewに追加
        self.view.addSubview(mapView)
        
        //取得精度の設定
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        //取得頻度の設定
        locationManager.distanceFilter = CLLocationDistance(dFilter)
        
        //位置情報の取得開始
        locationManager.startUpdatingLocation()
        
        //中心点の緯度経度の初期値(府大）
        let centerLongitude:CLLocationDegrees = 135.5076348
        let centerLatitude:CLLocationDegrees = 34.5477431
        let centerCoordinate:CLLocationCoordinate2D = CLLocationCoordinate2DMake(centerLatitude, centerLongitude)
        
        //縮尺
        let myLatDist:CLLocationDistance = 800
        let myLonDist:CLLocationDegrees = 800
        
        //Regionを作成
        let myRegion: MKCoordinateRegion = MKCoordinateRegionMakeWithDistance(centerCoordinate, myLatDist, myLonDist)
        
        //MapViewに反映
        mapView.setRegion(myRegion, animated: true)
        
        
        //ラベル初期化
        self.statusLabel = UILabel(frame: CGRect(x: 10, y: 20, width: self.view.frame.width, height: 50))
        self.threshLabel = UILabel(frame: CGRect(x: 10, y: 20, width: self.view.frame.width, height: 50))
        self.accuracyLabel = UILabel(frame: CGRect(x: 10, y: 50, width: self.view.frame.width, height: 50))
        self.statusLabel.text = ""
        self.threshLabel.text = "Thresh: " + Thresh.description + "m"
        self.accuracyLabel.text = ""
        //view.addSubview(self.statusLabel)
        view.addSubview(self.threshLabel)
        view.addSubview(self.accuracyLabel)
        
    }
    
    //画面が再表示される
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //ビーコン距離の測定を再開する
        if(self.isBeaconRanging == false){
            self.locationManager.startRangingBeacons(in: self.beaconRegion)
            self.isBeaconRanging = true
        }
    }
    
    //画面が非表示になるとき
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        //ビーコン距離の測定を停止する
        if(self.isBeaconRanging == true){
            self.locationManager.stopRangingBeacons(in: self.beaconRegion)
            self.isBeaconRanging = false
        }
        
    }

    //メモリリークになるとき
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //__________________________________________________________ここからマップに関するメソッド
    
    //(Delegate)位置情報取得に成功したときに呼び出されるデリゲート
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        //現在地の緯度・経度を取得
        self.latitude = manager.location!.coordinate.latitude
        self.longitude = manager.location!.coordinate.longitude
        
        //閾値で設定したビーコン領域の外にいる
        if(insideThresh == false){
            //MapViewにピンが存在しない
            if(mapView.annotations.count == 0){
                
                //MapViewの中心をピンの座標にする
                setCenter()
                
                //pinを表示する
                let now = NSDate()
                let dateFormatter = DateFormatter()
                dateFormatter.locale = NSLocale(localeIdentifier: "ja_JP") as Locale!
                dateFormatter.timeStyle = .medium
                dateFormatter.dateStyle = .medium
                
                //座標を設定
                let center:CLLocationCoordinate2D = CLLocationCoordinate2DMake(self.latitude, self.longitude)
                self.pin.coordinate = center
                
                //タイトルを設定
                self.pin.title = dateFormatter.string(from: now as Date)
                self.pin.subtitle = "自転車"
                
                //MapViewにピンを追加
                mapView.addAnnotation(self.pin)
                
                //UIAlertでダイアログを表示
                let alert: UIAlertController = UIAlertController(title: self.pin.title, message: "自転車の位置を記録しました", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: {action in print("Action OK")})
                alert.addAction(action)
                present(alert, animated: true, completion: nil)
                
            }
            //MapViewに既にピンが存在する
            else{
                
                //既に自転車と現在地までに直線が引かれている場合は削除する
                if(mapView.overlays.count > 0){
                    mapView.remove(self.line)
                    //mapView.remove(self.route as! MKOverlay)
                }
                
                //始点（現在地）
                let startCoordinate = CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
                
                //終点（自転車）
                let endCoordinate = CLLocationCoordinate2D(latitude: self.pin.coordinate.latitude, longitude: self.pin.coordinate.longitude)
                
                //始点と終点の座標
                var lineLocation:[CLLocationCoordinate2D] = [endCoordinate,startCoordinate]
                
                
                /*
                // 現在地と目的地のMKPlacemarkを生成
                let fromPlacemark = MKPlacemark(coordinate:startCoordinate, addressDictionary:nil)
                let toPlacemark   = MKPlacemark(coordinate:endCoordinate, addressDictionary:nil)
                
                // MKPlacemark から MKMapItem を生成
                let fromItem = MKMapItem(placemark:fromPlacemark)
                let toItem   = MKMapItem(placemark:toPlacemark)
                
                // MKMapItem をセットして MKDirectionsRequest を生成
                let request = MKDirectionsRequest()
                
                request.source = fromItem
                request.destination = toItem
                request.requestsAlternateRoutes = false // 単独の経路を検索
                request.transportType = MKDirectionsTransportType.any
                
                let directions = MKDirections(request:request)
                
                
                directions.calculate(completionHandler: {
                    (response:MKDirectionsResponse!, error:NSError!) -> Void in
                    
                    if (error != nil || response.routes.isEmpty) {
                        return
                    }
                    
                    self.route = response.routes[0] as MKRoute
                    
                    // 経路を描画
                    self.mapView.add(self.route.polyline)

                } as! MKDirectionsHandler)
                 
                //ここまで地図上に自転車と現在地の経路を表示をするコード
                //なぜかエラーのため、コメントアウトして地図上には直線を引くことにする
                 
                */
                
                
                //ライン（直線）を初期化する
                self.line = MKPolyline(coordinates: &lineLocation, count: 2)
                
                //MapViewにピンと現在地までのラインを描画する
                mapView.add(self.line)
                
            }
        }
        //閾値で設定したビーコン領域の中にいる
        else{
            
            //MapViewの中心を現在地にする
            setCenter()
            
            //MapViewにピンが存在する場合は削除する
            if(mapView.annotations.count > 0){
                mapView.removeAnnotation(self.pin)
                
                //UIAlertでダイアログを表示
                let alert: UIAlertController = UIAlertController(title: "おかえりなさい！", message: "自転車の位置に帰ってきました", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: {action in print("Action OK")})
                alert.addAction(action)
                present(alert, animated: true, completion: nil)
                
            }
            
            //MapViewにラインが存在する場合は削除する
            if(mapView.overlays.count > 0){
                mapView.remove(self.line)
//                mapView.remove(self.route as! MKOverlay)
            }
        }
    }
    
    //描画メソッド実行時の呼び出しメソッド
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        let testRender = MKPolylineRenderer(overlay: overlay)
        
        //直線の幅を設定
        testRender.lineWidth = 3
        
        //直線の色を設定
        testRender.strokeColor = UIColor.red
        
        return testRender
    }
    
    //(Delegate)位置情報取得に失敗したときに呼び出されるデリゲート
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得に失敗")
    }
    
    //マップの再描画
    func setCenter(){
        let centerLat:CLLocationDegrees = self.latitude
        let centerLon:CLLocationDegrees = self.longitude
        let centerCoordinate:CLLocationCoordinate2D = CLLocationCoordinate2DMake(centerLat, centerLon)
        
        //MapViewの中心を現在地に設定
        mapView.setCenter(centerCoordinate, animated: true)
        
    }
    
    //____________________________________________________ここまでマップに関するメソッド
    
    
    //____________________________________________________ここからビーコンに関するメソッド
    
    //(Delegate)位置情報サービスの利用許可ステータスの変化で呼び出される
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        switch (status) {
        case .authorizedAlways:
            //ビーコン領域の観測を開始する
            manager.startMonitoring(for: self.beaconRegion)
            break;
        default:
            break;
        }
    }
    
    //(Delegate)領域観測を開始したときに呼び出される
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        //この時点でビーコン領域にいる可能性があるためステータスのチェックを呼び出す
        manager.requestState(for: self.beaconRegion)
    }
    
    //(Delegate)ビーコン領域のステータスを受け取る
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        let statusText = "Status: "
        
        switch (state) {
        case .inside:
            print("inside")
            //すでにビーコン領域内にいる場合は、距離測定を開始する
            if(self.isBeaconRanging == false){
                manager.startRangingBeacons(in: self.beaconRegion)
                self.isBeaconRanging = true
            }
            self.statusLabel.text = statusText + "Inside"
            break;
        case .outside:
            print("outside")
            self.statusLabel.text = statusText + "Outside"
            break;
        case .unknown:
            print("unknown")
            self.statusLabel.text = statusText + "Unknown"
            self.accuracyLabel.text = ""
            break;
        }
    }
    
    //(Delegate)距離の測定結果を受け取る(測定開始後、1秒ごとに呼ばれる)
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        if(beacons.count > 0){
            
            //ビーコンから閾値以内に入っているとき
            if(beacons[0].accuracy > 0){
                
                //ラベルに表示
                let accuracyText = NSString(format: "%.2f", beacons[0].accuracy) as String
                self.accuracyLabel.text = "Accuracy: " + accuracyText + "m"
                
                if(beacons[0].accuracy < Thresh){
                    self.insideThresh = true
                }else{
                    self.insideThresh = false
                }
            }else{
                
            }
            
        }
        
    }
    
    //(Delegate)ビーコン領域に入った
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
        //距離の測定を開始する
        if(self.isBeaconRanging == false){
            manager.startRangingBeacons(in: self.beaconRegion)
            self.isBeaconRanging = true
        }
        
    }
    
    //(Delegate)ビーコン領域を出た
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        //距離の測定を終了する
        manager.stopRangingBeacons(in: self.beaconRegion)
        self.isBeaconRanging = false
        
        //ラベルに測定不能を表示
        self.accuracyLabel.text = "Accuracy: 測定不能"

    }
    
    //_______________________________________________________ここまでビーコンに関するメソッド


}

