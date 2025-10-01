package com.example.blipchat

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.charset.StandardCharsets
import java.util.*

class BleAdvertisingPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothManager: BluetoothManager? = null
    
    private var serviceUuid: String? = null
    private var characteristicUuid: String? = null
    private var isAdvertising = false
    private var isScanning = false
    private val connectedGatts = mutableListOf<BluetoothGatt>()

    companion object {
        private const val TAG = "BleAdvertisingPlugin"
        private const val CHANNEL = "blipchat/ble_advertising"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        initializeBluetooth()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopAdvertising()
    }

    private fun initializeBluetooth() {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startAdvertising" -> {
                val serviceUuidArg = call.argument<String>("serviceUuid")
                val characteristicUuidArg = call.argument<String>("characteristicUuid")
                val deviceName = call.argument<String>("deviceName")
                
                if (serviceUuidArg != null && characteristicUuidArg != null) {
                    serviceUuid = serviceUuidArg
                    characteristicUuid = characteristicUuidArg
                    startAdvertising(deviceName ?: "BlipChat", result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                }
            }
            "stopAdvertising" -> {
                stopAdvertising()
                result.success(true)
            }
            "sendMessage" -> {
                val messageData = call.arguments as? Map<String, Any>
                if (messageData != null) {
                    sendMessage(messageData, result)
                } else {
                    result.error("INVALID_MESSAGE", "Invalid message data", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startAdvertising(deviceName: String, result: Result) {
        if (!checkBluetoothSupport()) {
            result.error("BLE_NOT_SUPPORTED", "BLE not supported on this device", null)
            return
        }

        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is not enabled", null)
            return
        }

        try {
            // Set up GATT server
            setupGattServer()
            
            // Start scanning for other devices
            startScanning()
            
            // Start advertising
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0)
                .build()

            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .setIncludeTxPowerLevel(false)
                .addServiceUuid(ParcelUuid.fromString(serviceUuid))
                .build()

            bluetoothAdapter?.name = deviceName
            bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting advertising", e)
            result.error("ADVERTISING_ERROR", "Failed to start advertising: ${e.message}", null)
        }
    }

    private fun setupGattServer() {
        bluetoothGattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
        
        val service = BluetoothGattService(
            UUID.fromString(serviceUuid),
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        
        val characteristic = BluetoothGattCharacteristic(
            UUID.fromString(characteristicUuid),
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        
        service.addCharacteristic(characteristic)
        bluetoothGattServer?.addService(service)
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d(TAG, "Advertising started successfully")
            isAdvertising = true
            channel.invokeMethod("onAdvertisingStateChanged", true)
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "Advertising failed with error code: $errorCode")
            isAdvertising = false
            channel.invokeMethod("onAdvertisingStateChanged", false)
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            if (characteristic?.uuid.toString().equals(characteristicUuid, ignoreCase = true)) {
                value?.let { data ->
                    try {
                        val messageJson = String(data, StandardCharsets.UTF_8)
                        Log.d(TAG, "Received message JSON: $messageJson")
                        
                        // Forward the JSON string to Flutter - Flutter will parse it
                        channel.invokeMethod("onMessageReceived", messageJson)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing received message", e)
                    }
                }
            }
            
            if (responseNeeded) {
                bluetoothGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    0,
                    null
                )
            }
        }
    }

    private fun sendMessage(messageData: Map<String, Any>, result: Result) {
        try {
            val messageJson = messageData.toString() // Convert to JSON string
            val messageBytes = messageJson.toByteArray(StandardCharsets.UTF_8)
            
            Log.d(TAG, "Broadcasting message to ${connectedGatts.size} connected devices")
            
            // Send to all connected GATT clients via server
            bluetoothGattServer?.getService(UUID.fromString(serviceUuid))?.let { service ->
                service.getCharacteristic(UUID.fromString(characteristicUuid))?.let { characteristic ->
                    characteristic.value = messageBytes
                    // Notify all connected clients
                    connectedGatts.forEach { gatt ->
                        try {
                            bluetoothGattServer?.notifyCharacteristicChanged(gatt.device, characteristic, false)
                            Log.d(TAG, "Notified device: ${gatt.device.address}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error notifying device ${gatt.device.address}: $e")
                        }
                    }
                }
            }
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending message: $e")
            result.error("SEND_ERROR", "Failed to send message", e.message)
        }
    }

    private fun stopAdvertising() {
        if (isAdvertising) {
            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            bluetoothGattServer?.close()
            isAdvertising = false
            channel.invokeMethod("onAdvertisingStateChanged", false)
            Log.d(TAG, "Advertising stopped")
        }
        
        if (isScanning) {
            bluetoothLeScanner?.stopScan(scanCallback)
            isScanning = false
            Log.d(TAG, "Scanning stopped")
        }
        
        // Disconnect all GATT connections
        connectedGatts.forEach { gatt ->
            gatt.disconnect()
            gatt.close()
        }
        connectedGatts.clear()
    }

    private fun startScanning() {
        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid.fromString(serviceUuid))
            .build()
        
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        
        bluetoothLeScanner?.startScan(listOf(scanFilter), scanSettings, scanCallback)
        isScanning = true
        Log.d(TAG, "Started scanning for devices")
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.device?.let { device ->
                Log.d(TAG, "Found device: ${device.name} - ${device.address}")
                // Connect to the device
                connectToDevice(device)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "Scan failed with error: $errorCode")
        }
    }

    private fun connectToDevice(device: BluetoothDevice) {
        // Check if already connected
        if (connectedGatts.any { it.device.address == device.address }) {
            return
        }
        
        Log.d(TAG, "Connecting to device: ${device.address}")
        val gatt = device.connectGatt(context, false, gattCallback)
        connectedGatts.add(gatt)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected to GATT server")
                    gatt?.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Disconnected from GATT server")
                    connectedGatts.remove(gatt)
                    gatt?.close()
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "Services discovered")
                gatt?.getService(UUID.fromString(serviceUuid))?.let { service ->
                    service.getCharacteristic(UUID.fromString(characteristicUuid))?.let { char ->
                        // Enable notifications
                        gatt.setCharacteristicNotification(char, true)
                        Log.d(TAG, "Found characteristic, ready to communicate")
                    }
                }
            }
        }
    }

    private fun checkBluetoothSupport(): Boolean {
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) &&
                bluetoothAdapter != null &&
                bluetoothLeAdvertiser != null
    }
}