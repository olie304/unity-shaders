// Auroras by nimitz 2017 (twitter: @stormoid) https://www.shadertoy.com/view/XtGGRt
// Ported to World-Space Unity-HLSL and modified by olie304 (https://github.com/olie304)
// This skybox shader functions on any shape skybox assuming it moves with the camera

Shader "Unlit/Aurora"
{
    Properties
    {
        _AuroraSpeed ("Aurora Speed Multiplier", Float) = 5.0
    }
    SubShader
    {
        Tags 
        { 
            "Queue" = "Background"
            "RenderType"="Background"
            "PreviewType" = "Skybox"
        }
        Cull Front

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            float4 _MainTex_ST;
            float _AuroraSpeed;
            
            struct appdata
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 worldSpacePosition : TEXCOORD1;
                float4 vertex : SV_POSITION;
                UNITY_FOG_COORDS(1)

            };
            
            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldSpacePosition = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            #define time _Time.y
            #define targetRes float2(8192.0/8.0,4096.0/8.0) // Change this to RenderTarget size if it is provided. Large values may cause spatial incoherency.
            #define uvCoords i.uv  // [0.0-1.0] Expected
            #define worldCoords i.worldSpacePosition  // World-Space vertex coords

            float2x2 mm2(in float a){float c = cos(a), s = sin(a);return float2x2(c,s,-s,c);}
            float tri(in float x){return clamp(abs(frac(x)-.5),0.01,0.49);}
            float2 tri2(in float2 p){return float2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

            float triNoise2d(in float2 p, float spd)
            {
                float2x2 m2 = float2x2(0.95534, 0.29552, -0.29552, 0.95534);
                float z=1.8;
                float z2=2.5;
                float rz = 0.;
                p = mul(p, mm2(p.x*0.06));  // Aurora Stretch
                float2 bp = p;
                for (float i=0.; i<5.; i++ )
                {
                    float2 dg = tri2(bp*1.85)*.75;
                    dg = mul(dg, mm2(time*spd));
                    p -= dg/z2;

                    bp *= 1.3;
                    z2 *= .45;
                    z *= .42;
                    p *= 1.21 + (rz-1.0)*.02;
                    
                    rz += tri(p.x+tri(p.y))*z;
                    p = mul(p, -m2);
                }
                return clamp(1./pow(rz*29., 1.3),0.,.55);
            }

            float hash21(in float2 n){ return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453); }
            float4 aurora(float3 ro, float3 rd, float4 pos)
            {
                //float4 col = float4(0.,0.,0.,0.);
                float4 col = float4(0.03,0.,0.,0.);
                float4 avgCol = float4(0.,0.,0.,0.);
                
                for(float i=0.;i<90.;i++)
                {
                    float of = 0.006*hash21(pos.xy)*smoothstep(0.,15., i);
                    float pt = ((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
                    pt -= of;
                    float3 bpos = ro + pt*rd;
                    float2 p = bpos.zx;
                    //float rzt = triNoise2d(p, 0.06);  // Original
                    //float rzt = triNoise2d(p, 0.3);  // Faster animation
                    float rzt = triNoise2d(p, 0.06 * _AuroraSpeed);
                    float4 col2 = float4(0.,0.,0., rzt);
                    //col2.rgb = (sin(1.-float3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;  // Original
                    col2.rgb = (sin(1.-float3(i < 5. ? 0.0 : 2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;  // Better colors
                    avgCol =  lerp(avgCol, col2, .5);
                    col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
                    
                }
                
                col *= (clamp(rd.y*15.+.4,0.,1.));
                
                // Alternate colors
                //return clamp(pow(col,float4(1.3))*1.5,0.,1.);
                //return clamp(pow(col,float4(1.7))*2.,0.,1.);
                //return clamp(pow(col,float4(1.5))*2.5,0.,1.);
                //return clamp(pow(col,float4(1.8))*1.5,0.,1.);
                
                //return smoothstep(0.,1.1,pow(col,float4(1.))*1.5);
                return col*1.8;
                //return pow(col,float4(1.))*2.
            }

            //-------------------Background and Stars--------------------

            float3 nmzHash33(float3 q)
            {
                uint3 p = uint3(int3(q));
                p = p*uint3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
                p = p.yzx*(p.zxy^(p >> 3U));
                return float3(p^(p >> 16U))*(1.0/float3(0xffffffffU,0xffffffffU,0xffffffffU));
            }

            float3 stars(in float3 p)
            {
                float3 c = float3(0., 0., 0.);
                float res = targetRes.x*1.;
                
                for (float i=0.;i<4.;i++)
                {
                    float3 q = float3(frac(p*(.15*res))-0.5);
                    float3 id = float3(floor(p*(.15*res)));
                    float2 rn = nmzHash33(id).xy;
                    float c2 = 1.-smoothstep(0.,.6,length(q));
                    c2 *= step(rn.x,.0005+i*i*0.001);
                    c += c2*(lerp(float3(1.0,0.49,0.1),float3(0.75,0.9,1.),rn.y)*0.1+0.9);
                    p *= 1.3;
                }
                return c*c*.8;
            }

            float3 bg(in float3 rd)
            {
                float sd = dot(normalize(float3(-0.5, -0.6, 0.9)), rd)*0.5+0.5;
                sd = pow(sd, 5.);
                float3 col = lerp(float3(0.05,0.1,0.2), float3(0.1,0.05,0.2), sd);
                return col*.63;
            }

            float3x3 AngleAxis3x3(float angle, float3 axis)
            {
                float c, s;
                sincos(angle, s, c);

                float t = 1. - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float3x3(
                    t * x * x + c,      t * x * y - s * z,  t * x * z + s * y,
                    t * x * y + s * z,  t * y * y + c,      t * y * z - s * x,
                    t * x * z - s * y,  t * y * z + s * x,  t * z * z + c
                );
            }
            
            float4 frag (v2f i) : SV_Target
            {
                float2 q = float2(uvCoords.x, targetRes.y-uvCoords.y) / targetRes;
                float2 p = q - 0.5;
                p.x*=targetRes.x/targetRes.y;
                
                float3 ro = float3(0.,0.,-6.7);
                float3 rd = normalize(worldCoords.xyz);
                float2 mo = float2(0.,0.);
                mo = (mo==float2(-.5,-.5))?mo=float2(-0.1,0.1):mo;
                //rd.xyz = mul(rd.xyz, AngleAxis3x3(3.14159274 * 0.5, float3(1,0,0))); // Use this to rotate for different game engines
                
                float3 col = float3(0., 0., 0.);
                float3 brd = rd;
                float fade = smoothstep(0.,0.01,abs(brd.y))*0.1+0.9;
                
                col = bg(rd)*fade;
                
                if (rd.y > 0.){
                    float4 aur = smoothstep(0.,1.5,aurora(ro,rd, float4(uvCoords.x, targetRes.y-uvCoords.y, 0., 0.)))*fade;
                    col += stars(rd);
                    col = col*(1.-aur.a) + aur.rgb;
                }
                else //Reflections
                {
                    rd.y = abs(rd.y);
                    col = bg(rd)*fade*0.6;
                    float4 aur = smoothstep(0.0,2.5,aurora(ro,rd, float4(uvCoords.x, targetRes.y-uvCoords.y, 0., 0.)));
                    col += stars(rd)*0.1;
                    col = col*(1.-aur.a) + aur.rgb;
                    float3 pos = ro + ((0.5-ro.y)/rd.y)*rd;
                    float nz2 = triNoise2d(pos.xz*float2(.5,.7), 0.);
                    col += lerp(float3(0.2,0.25,0.5)*0.08,float3(0.3,0.3,0.5)*0.7, nz2*0.4);
                }
                
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}
