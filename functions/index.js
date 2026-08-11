const {onRequest} = require("firebase-functions/v2/https");
const {RtcTokenBuilder, RtcRole} = require("agora-token");

exports.generateAgoraToken = onRequest({cors: true}, (req, res) => {
  const appId = "3a54c447b558405da3e87b1177ccc463";
  const appCertificate = "046ee486f02a4f80a4b0594fb66bd33d";

  const channelName = req.body.channelName;
  const uid = req.body.uid || 0;

  if (!channelName) {
    return res.status(400).json({error: "channelName is required"});
  }

  const role = RtcRole.PUBLISHER;
  const expirationTimeInSeconds =14400;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        privilegeExpiredTs,
        privilegeExpiredTs,
    );

    return res.status(200).json({token: token});
  } catch (error) {
    console.error("Error generating token:", error);
    return res.status(500).json({error: "Failed to generate token"});
  }
});
