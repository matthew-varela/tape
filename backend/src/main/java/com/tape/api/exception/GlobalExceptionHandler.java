package com.tape.api.exception;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Normalizes all error responses to {@code { "message": "..." }} so iOS and
 * Android clients always receive the same error shape regardless of which
 * exception Spring throws internally.
 *
 * Status codes follow the contract:
 *   401 — missing or invalid token
 *   403 — insufficient permissions or tier
 *   404 — resource not found
 *   409 — conflict (e.g. duplicate signup)
 *   400 — validation / bad request
 *   500 — unexpected server error
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    /** Handles {@link ResponseStatusException} thrown by services and controllers. */
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> handleResponseStatus(ResponseStatusException ex) {
        return body(ex.getStatusCode(), ex.getReason() != null ? ex.getReason() : ex.getMessage());
    }

    /**
     * Handles bean-validation failures ({@code @Valid} on request bodies).
     * Joins all field errors into a single human-readable message.
     */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(FieldError::getDefaultMessage)
            .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest()
            .body(Map.of("message", message.isBlank() ? "Invalid request" : message));
    }

    /** Catch-all for unexpected server errors — never leaks stack traces to clients. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleUnexpected(Exception ex) {
        logger.error("Unhandled exception", ex);
        return body(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }

    private static ResponseEntity<Map<String, String>> body(HttpStatusCode status, String message) {
        return ResponseEntity.status(status).body(Map.of("message", message));
    }
}
