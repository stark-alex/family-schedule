package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type mockS3 struct {
	getBody string
	getErr  error
	putErr  error
}

func (m *mockS3) GetObject(_ context.Context, _ *s3.GetObjectInput, _ ...func(*s3.Options)) (*s3.GetObjectOutput, error) {
	if m.getErr != nil {
		return nil, m.getErr
	}
	return &s3.GetObjectOutput{Body: io.NopCloser(strings.NewReader(m.getBody))}, nil
}

func (m *mockS3) PutObject(_ context.Context, _ *s3.PutObjectInput, _ ...func(*s3.Options)) (*s3.PutObjectOutput, error) {
	return &s3.PutObjectOutput{}, m.putErr
}

func req(method, body string) events.APIGatewayV2HTTPRequest {
	return events.APIGatewayV2HTTPRequest{
		Body: body,
		RequestContext: events.APIGatewayV2HTTPRequestContext{
			HTTP: events.APIGatewayV2HTTPRequestContextHTTPDescription{Method: method},
		},
	}
}

func TestGetSchedule_OK(t *testing.T) {
	yaml := "days:\n  - name: Sunday\n"
	h := &handler{s3: &mockS3{getBody: yaml}, bucket: "test", scheduleKey: "schedule.yaml"}

	resp, err := h.handle(context.Background(), req(http.MethodGet, ""))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Errorf("want 200, got %d", resp.StatusCode)
	}
	if resp.Body != yaml {
		t.Errorf("want %q, got %q", yaml, resp.Body)
	}
	if resp.Headers["Content-Type"] != "text/yaml; charset=utf-8" {
		t.Errorf("unexpected Content-Type: %q", resp.Headers["Content-Type"])
	}
}

func TestGetSchedule_S3Error(t *testing.T) {
	h := &handler{s3: &mockS3{getErr: errors.New("s3 unavailable")}, bucket: "test", scheduleKey: "schedule.yaml"}

	resp, err := h.handle(context.Background(), req(http.MethodGet, ""))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("want 500, got %d", resp.StatusCode)
	}
}

func TestPutSchedule_OK(t *testing.T) {
	yaml := "days:\n  - name: Sunday\n"
	h := &handler{s3: &mockS3{}, bucket: "test", scheduleKey: "schedule.yaml"}

	resp, err := h.handle(context.Background(), req(http.MethodPut, yaml))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("want 204, got %d", resp.StatusCode)
	}
}

func TestPutSchedule_InvalidYAML(t *testing.T) {
	h := &handler{s3: &mockS3{}, bucket: "test", scheduleKey: "schedule.yaml"}

	resp, err := h.handle(context.Background(), req(http.MethodPut, "days: [\nunot closed"))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestPutSchedule_S3Error(t *testing.T) {
	yaml := "days:\n  - name: Sunday\n"
	h := &handler{s3: &mockS3{putErr: errors.New("write failed")}, bucket: "test"}

	resp, err := h.handle(context.Background(), req(http.MethodPut, yaml))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("want 500, got %d", resp.StatusCode)
	}
}

func TestUnsupportedMethod(t *testing.T) {
	h := &handler{s3: &mockS3{}, bucket: "test", scheduleKey: "schedule.yaml"}

	resp, err := h.handle(context.Background(), req(http.MethodDelete, ""))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("want 405, got %d", resp.StatusCode)
	}
}
