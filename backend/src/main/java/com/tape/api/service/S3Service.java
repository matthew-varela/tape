package com.tape.api.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import java.time.Duration;
import java.util.Map;
import java.util.UUID;

@Service
public class S3Service {

    @Value("${aws.s3.bucket}")
    private String bucket;

    private final S3Presigner presigner;

    public S3Service(@Value("${aws.s3.region}") String region,
                     @Value("${aws.s3.access-key}") String accessKey,
                     @Value("${aws.s3.secret-key}") String secretKey) {
        if (accessKey != null && !accessKey.isEmpty()) {
            this.presigner = S3Presigner.builder()
                .region(software.amazon.awssdk.regions.Region.of(region))
                .credentialsProvider(
                    software.amazon.awssdk.auth.credentials.StaticCredentialsProvider.create(
                        software.amazon.awssdk.auth.credentials.AwsBasicCredentials.create(accessKey, secretKey)
                    )
                )
                .build();
        } else {
            this.presigner = null;
        }
    }

    public Map<String, String> generatePresignedUploadUrl(String filename) {
        if (presigner == null) {
            return Map.of(
                "uploadUrl", "https://" + bucket + ".s3.amazonaws.com/videos/" + filename,
                "videoUrl", "https://" + bucket + ".s3.amazonaws.com/videos/" + filename,
                "message", "S3 not configured -- returning placeholder URL"
            );
        }

        String key = "videos/" + UUID.randomUUID() + "/" + filename;

        PutObjectRequest objectRequest = PutObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .contentType("video/mp4")
            .build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
            .signatureDuration(Duration.ofMinutes(15))
            .putObjectRequest(objectRequest)
            .build();

        var presigned = presigner.presignPutObject(presignRequest);

        return Map.of(
            "uploadUrl", presigned.url().toString(),
            "videoUrl", "https://" + bucket + ".s3.amazonaws.com/" + key
        );
    }
}
