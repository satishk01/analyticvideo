import "./App.css";
import { VideoTable } from "./VideoTable/VideoTable";
import { VideoUpload } from "./VideoUpload/VideoUpload";
import awsExports from "./aws-exports";
import { S3Client } from "@aws-sdk/client-s3";
import { BedrockRuntimeClient } from "@aws-sdk/client-bedrock-runtime";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import ProtectedRoute from "./components/ProtectedRoute/ProtectedRoute";

import Container from "react-bootstrap/Container";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/Col";
import Navbar from "react-bootstrap/Navbar";
import Button from "react-bootstrap/Button";
import { useEffect, useState } from "react";

const REGION = awsExports.aws_project_region;

function AppContent() {
  const [s3Client, setS3Client] = useState(null);
  const [bedrockClient, setBedrockClient] = useState(null);
  const { user, logout, getAuthHeaders } = useAuth();

  useEffect(() => {
    const initializeClients = async () => {
      // For demo purposes, we'll use a simplified credential approach
      // In production, you'd want to use proper IAM roles or STS tokens
      
      setS3Client(new S3Client({
        region: REGION,
        // Note: In a real implementation, you'd configure proper credentials here
        // For demo purposes, the backend will handle AWS service calls
      }));

      setBedrockClient(new BedrockRuntimeClient({
        region: REGION,
        // Note: In a real implementation, you'd configure proper credentials here
        // For demo purposes, the backend will handle AWS service calls
      }));
    };

    initializeClients();
  }, []);

  const handleLogout = async () => {
    await logout();
  };

  if (!s3Client || !bedrockClient) return (<div>Loading...</div>)

  return (
    <div className="App" key="app-root">
      <Navbar expand="lg" className="bg-body-tertiary">
        <Container>
          <Navbar.Brand href="#">Video Understanding Solution</Navbar.Brand>
          <Navbar.Collapse className="justify-content-end">
            <Navbar.Text className="me-3">
              Welcome, {user?.username}
            </Navbar.Text>
            <Button variant="outline-secondary" size="sm" onClick={handleLogout}>
              Logout
            </Button>
          </Navbar.Collapse>
        </Container>
      </Navbar>
      <Container id="VideoTableContainer">
        <Row>
          <Col></Col>
          <Col xs={10}>
            <Row>
              <Col>
                <VideoUpload
                  s3Client={s3Client}
                  bucketName={awsExports.bucket_name}
                  rawFolder={awsExports.raw_folder}
                />
              </Col>
            </Row>
            <Row>
              <Col>
                <hr></hr>
              </Col>
            </Row>
            <Row>
              <Col>
                <VideoTable
                  bucketName={awsExports.bucket_name}
                  s3Client={s3Client}
                  bedrockClient={bedrockClient}
                  fastModelId={awsExports.fast_model_id}
                  balancedModelId={awsExports.balanced_model_id}
                  rawFolder={awsExports.raw_folder}
                  summaryFolder={awsExports.summary_folder}
                  videoScriptFolder={awsExports.video_script_folder}
                  videoCaptionFolder={awsExports.video_caption_folder}
                  entitySentimentFolder={awsExports.entity_sentiment_folder}
                  transcriptionFolder={awsExports.transcription_folder}
                  restApiUrl={awsExports.rest_api_url}
                  videosApiResource={awsExports.videos_api_resource}
                  authHeaders={getAuthHeaders()}
                ></VideoTable>
              </Col>
            </Row>
          </Col>
          <Col></Col>
        </Row>
      </Container>
    </div>
  );
}

function App() {
  return (
    <AuthProvider authApiUrl={awsExports.auth_api_url}>
      <ProtectedRoute>
        <AppContent />
      </ProtectedRoute>
    </AuthProvider>
  );
}

export default App;
