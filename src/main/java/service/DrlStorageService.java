package com.function.service;

import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.models.ListBlobsOptions;
import java.util.HashMap;
import java.util.Map;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class DrlStorageService {

    private static final String CONTAINER_NAME = "drools-rules";
    private final BlobContainerClient containerClient;

    public DrlStorageService() {
        String connectionString = System.getenv("AZURE_STORAGE_CONNECTION_STRING");
        if (connectionString == null || connectionString.isBlank()) {
            System.err.println("[DrlStorageService] AZURE_STORAGE_CONNECTION_STRING 未設定");
            containerClient = null;
            return;
        }

        BlobServiceClient serviceClient = new BlobServiceClientBuilder()
                .connectionString(connectionString)
                .buildClient();

        containerClient = serviceClient.getBlobContainerClient(CONTAINER_NAME);
        if (!containerClient.exists()) {
            containerClient.create();
            System.out.println("[DrlStorageService] Container created: " + CONTAINER_NAME);
        }
    }

    public void uploadDrl(String blobKey, String drlContent) {
        if (containerClient == null) {
            System.err.println("[DrlStorageService] 無法上傳，containerClient 未初始化");
            return;
        }
        BlobClient blobClient = containerClient.getBlobClient(blobKey);
        byte[] bytes = drlContent.getBytes(StandardCharsets.UTF_8);
        blobClient.upload(new ByteArrayInputStream(bytes), bytes.length, true);
        System.out.println("[DrlStorageService] Uploaded: " + blobKey);
    }

    public String downloadDrl(String blobKey) {
        if (containerClient == null) {
            System.err.println("[DrlStorageService] 無法下載，containerClient 未初始化");
            return null;
        }
        BlobClient blobClient = containerClient.getBlobClient(blobKey);
        if (!blobClient.exists()) {
            return null;
        }
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        blobClient.downloadStream(outputStream);
        return outputStream.toString(StandardCharsets.UTF_8);
    }

    public List<String> listDrls(String prefix) {
        if (containerClient == null) {
            System.err.println("[DrlStorageService] 無法列出，containerClient 未初始化");
            return Collections.emptyList();
        }
        List<String> keys = new ArrayList<>();
        containerClient.listBlobs(new ListBlobsOptions().setPrefix(prefix), null)
                .forEach(item -> keys.add(item.getName()));
        System.out.println("[DrlStorageService] listDrls('" + prefix + "') -> " + keys);
        return keys;
    }
    // 在類別頂部加入靜態單例（供 KieSessionService 靜態呼叫）
private static final DrlStorageService INSTANCE = new DrlStorageService();

/**
 * 靜態方法：讀取指定資料夾前綴下的所有 DRL 檔案
 * 回傳 Map<檔名, DRL內容>，供 KieSessionService 動態建置容器使用
 *
 * @param folderPath 例如 "salary" 或 "salary/companyA"
 */
public static Map<String, String> readRules(String folderPath) {
    if (INSTANCE.containerClient == null) {
        System.err.println("[DrlStorageService] readRules 失敗，containerClient 未初始化");
        return Collections.emptyMap();
    }
    String prefix = folderPath.endsWith("/") ? folderPath : folderPath + "/";
    List<String> keys = INSTANCE.listDrls(prefix);
    Map<String, String> result = new HashMap<>();
    for (String blobKey : keys) {
        String content = INSTANCE.downloadDrl(blobKey);
        if (content != null && !content.isBlank()) {
            String fileName = blobKey.substring(prefix.length());
            if (!fileName.isBlank()) {
                result.put(fileName, content);
            }
        }
    }
    return result;
}
}